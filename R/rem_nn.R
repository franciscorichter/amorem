#' Control parameters for the neural-network backend of rem()
#'
#' Collects the architecture and training hyper-parameters used by
#' `rem(method = "nn")`. The network is a multilayer perceptron scoring each
#' candidate in a case-control stratum; training maximizes the same
#' conditional-logistic partial likelihood as `method = "clogit"` (softmax over
#' each risk set), so the neural backend is a drop-in nonlinear counterpart of
#' the linear conditional logit.
#'
#' @param hidden Integer vector of hidden-layer sizes, e.g. `c(16, 8)`. Use
#'   `integer(0)` for no hidden layer (recovers a linear conditional logit fit
#'   by gradient descent).
#' @param activation Hidden-layer activation: `"relu"` or `"tanh"`.
#' @param epochs Maximum number of full-batch training epochs.
#' @param lr Adam learning rate.
#' @param l2 L2 penalty (weight decay) on the weights (not the biases).
#' @param validation Fraction of strata held out for validation / early
#'   stopping. Set to `0` to train on everything (no early stopping).
#' @param patience Early-stopping patience: training stops after this many
#'   epochs without improvement of the validation loss; the best parameters
#'   are restored.
#' @param standardize Z-score the features before training (recommended; the
#'   scaling is stored and re-applied by `predict()`).
#' @param seed Optional integer seed for reproducible initialization and
#'   validation split.
#' @param verbose Print the loss every 50 epochs.
#'
#' @return A list of class `"nn_control"`.
#' @seealso [rem()]
#' @export
nn_control <- function(hidden = c(16L, 8L), activation = c("relu", "tanh"),
                       epochs = 300L, lr = 1e-2, l2 = 1e-4,
                       validation = 0.2, patience = 25L,
                       standardize = TRUE, seed = NULL, verbose = FALSE) {
  activation <- match.arg(activation)
  hidden <- as.integer(hidden)
  if (any(hidden < 1L)) stop("`hidden` layer sizes must be positive integers.")
  if (lr <= 0) stop("`lr` must be positive.")
  if (validation < 0 || validation >= 1) stop("`validation` must be in [0, 1).")
  structure(list(hidden = hidden, activation = activation,
                 epochs = as.integer(epochs), lr = lr, l2 = l2,
                 validation = validation, patience = as.integer(patience),
                 standardize = isTRUE(standardize), seed = seed,
                 verbose = isTRUE(verbose)),
            class = "nn_control")
}

# ---------------------------------------------------------------------------
# Internal pure-R MLP machinery.
#
# The model scores every candidate row with an MLP; the loss is the negative
# conditional-logistic partial likelihood: for each stratum, softmax over its
# candidates' scores, cross-entropy that the observed event is selected.
# Gradients are exact (hand-derived) and unit-tested against numerical
# differentiation in test-rem-nn.R.
# ---------------------------------------------------------------------------

.nn_init <- function(p, hidden, seed = NULL) {
  if (!is.null(seed)) set.seed(seed)
  sizes <- c(p, hidden, 1L)
  layers <- vector("list", length(sizes) - 1L)
  for (l in seq_along(layers)) {
    nin <- sizes[l]; nout <- sizes[l + 1L]
    # He initialization
    layers[[l]] <- list(
      W = matrix(stats::rnorm(nin * nout, sd = sqrt(2 / nin)), nin, nout),
      b = rep(0, nout))
  }
  layers
}

.nn_forward <- function(layers, X, activation) {
  L <- length(layers)
  acts <- vector("list", L + 1L)   # acts[[l]] = input to layer l
  acts[[1L]] <- X
  for (l in seq_len(L)) {
    Z <- sweep(acts[[l]] %*% layers[[l]]$W, 2L, layers[[l]]$b, "+")
    if (l < L) {
      Z <- if (activation == "relu") pmax(Z, 0) else tanh(Z)
    }
    acts[[l + 1L]] <- Z
  }
  list(scores = drop(acts[[L + 1L]]), acts = acts)
}

# Per-stratum softmax + negative log partial likelihood and dL/dscores.
.nn_loss_grad <- function(scores, strat_id, is_event) {
  sid <- as.integer(factor(strat_id))               # contiguous 1..K ids
  m <- tapply(scores, sid, max)[sid]                # per-stratum max (stability)
  e <- exp(scores - m)
  denom <- rowsum(e, sid)[sid, 1L]
  prob <- e / denom
  n_strata <- max(sid)
  loss <- -sum(log(prob[is_event])) / n_strata
  grad <- (prob - as.numeric(is_event)) / n_strata  # d(-logPL)/d(scores)
  list(loss = loss, grad = grad, prob = prob)
}

.nn_backward <- function(layers, acts, dscores, activation, l2) {
  L <- length(layers)
  grads <- vector("list", L)
  delta <- matrix(dscores, ncol = 1L)
  for (l in seq(L, 1L)) {
    A <- acts[[l]]
    grads[[l]] <- list(W = crossprod(A, delta) + l2 * layers[[l]]$W,
                       b = colSums(delta))
    if (l > 1L) {
      delta <- delta %*% t(layers[[l]]$W)
      H <- acts[[l]]                       # post-activation output of layer l-1
      delta <- if (activation == "relu") delta * (H > 0) else delta * (1 - H^2)
    }
  }
  grads
}

.nn_adam_step <- function(layers, grads, state, lr, t,
                          beta1 = 0.9, beta2 = 0.999, eps = 1e-8) {
  for (l in seq_along(layers)) {
    for (nm in c("W", "b")) {
      g <- grads[[l]][[nm]]
      state[[l]][[nm]]$m <- beta1 * state[[l]][[nm]]$m + (1 - beta1) * g
      state[[l]][[nm]]$v <- beta2 * state[[l]][[nm]]$v + (1 - beta2) * g^2
      mhat <- state[[l]][[nm]]$m / (1 - beta1^t)
      vhat <- state[[l]][[nm]]$v / (1 - beta2^t)
      layers[[l]][[nm]] <- layers[[l]][[nm]] - lr * mhat / (sqrt(vhat) + eps)
    }
  }
  list(layers = layers, state = state)
}

# Fit the neural conditional-logistic model.
# X: numeric feature matrix [n_rows, p]; strat_id: stratum of each row;
# is_event: logical event indicator per row.
.rem_nn_fit <- function(X, strat_id, is_event, control, feature_names) {
  strat_id <- as.integer(factor(strat_id))
  scaler <- NULL
  if (control$standardize) {
    mu <- colMeans(X); sdv <- apply(X, 2L, stats::sd); sdv[sdv == 0] <- 1
    X <- sweep(sweep(X, 2L, mu, "-"), 2L, sdv, "/")
    scaler <- list(mean = mu, sd = sdv)
  }

  if (!is.null(control$seed)) set.seed(control$seed)
  strata <- unique(strat_id)
  val_strata <- integer(0)
  if (control$validation > 0 && length(strata) >= 10L) {
    val_strata <- sample(strata, max(1L, floor(control$validation * length(strata))))
  }
  in_val <- strat_id %in% val_strata
  tr <- !in_val

  layers <- .nn_init(ncol(X), control$hidden, seed = control$seed)
  state <- lapply(layers, function(ly) list(
    W = list(m = ly$W * 0, v = ly$W * 0), b = list(m = ly$b * 0, v = ly$b * 0)))

  history <- data.frame(epoch = integer(0), train = numeric(0), val = numeric(0))
  best <- list(loss = Inf, layers = layers, epoch = 0L)
  stall <- 0L
  for (t in seq_len(control$epochs)) {
    fw <- .nn_forward(layers, X[tr, , drop = FALSE], control$activation)
    lg <- .nn_loss_grad(fw$scores, strat_id[tr], is_event[tr])
    grads <- .nn_backward(layers, fw$acts, lg$grad, control$activation, control$l2)
    upd <- .nn_adam_step(layers, grads, state, control$lr, t)
    layers <- upd$layers; state <- upd$state

    val_loss <- NA_real_
    if (length(val_strata)) {
      fv <- .nn_forward(layers, X[in_val, , drop = FALSE], control$activation)
      val_loss <- .nn_loss_grad(fv$scores, strat_id[in_val], is_event[in_val])$loss
      if (val_loss < best$loss - 1e-6) {
        best <- list(loss = val_loss, layers = layers, epoch = t); stall <- 0L
      } else {
        stall <- stall + 1L
        if (stall >= control$patience) break
      }
    }
    history <- rbind(history, data.frame(epoch = t, train = lg$loss, val = val_loss))
    if (control$verbose && t %% 50L == 0L) {
      cat(sprintf("epoch %4d  train %.4f  val %s\n", t, lg$loss,
                  ifelse(is.na(val_loss), "-", sprintf("%.4f", val_loss))))
    }
  }
  if (length(val_strata)) layers <- best$layers

  # final pass over everything: log-likelihood, validation concordance
  fa <- .nn_forward(layers, X, control$activation)
  all_loss <- .nn_loss_grad(fa$scores, strat_id, is_event)
  n_strata <- length(unique(strat_id))
  concord <- function(rows) {
    if (!length(rows)) return(NA_real_)
    sid <- strat_id[rows]; sc <- fa$scores[rows]; ev <- is_event[rows]
    top <- tapply(seq_along(sc), sid, function(ix) ix[which.max(sc[ix])])
    mean(ev[as.integer(top)])
  }
  n_par <- sum(vapply(layers, function(l) length(l$W) + length(l$b), numeric(1)))

  structure(list(
    layers = layers, activation = control$activation, scaler = scaler,
    features = feature_names, control = control, history = history,
    logLik = -all_loss$loss * n_strata, n_strata = n_strata, n_par = n_par,
    concordance = list(all = concord(seq_along(is_event)),
                       validation = concord(which(strat_id %in% val_strata))),
    best_epoch = if (length(val_strata)) best$epoch else nrow(history)),
    class = "rem_nn_fit")
}

# ---- methods on the inner fit (rem methods delegate to object$fit) --------

#' @export
print.rem_nn_fit <- function(x, ...) {
  cat("Neural conditional-logistic REM fit\n")
  cat("  architecture : ", paste(c(length(x$features), x$control$hidden, 1L),
                                 collapse = " - "),
      "  (", x$activation, ")\n", sep = "")
  cat("  parameters   : ", x$n_par, "\n", sep = "")
  cat("  strata       : ", x$n_strata, "\n", sep = "")
  cat("  best epoch   : ", x$best_epoch, "\n", sep = "")
  if (!is.na(x$concordance$validation)) {
    cat("  val concord. : ", sprintf("%.3f", x$concordance$validation), "\n", sep = "")
  }
  invisible(x)
}

#' @export
summary.rem_nn_fit <- function(object, ...) {
  print(object)
  cat("\nFeatures: ", paste(object$features, collapse = ", "), "\n", sep = "")
  cat("In-sample concordance (event ranked first): ",
      sprintf("%.3f", object$concordance$all), "\n", sep = "")
  cat("log partial likelihood: ", sprintf("%.2f", object$logLik), "\n", sep = "")
  cat("\nNo coefficient table: the effect surface is learned by the network.\n")
  cat("Use plot(fit, type = \"pdp\") for per-feature partial-dependence curves.\n")
  invisible(object)
}

#' @export
coef.rem_nn_fit <- function(object, ...) {
  message("rem(method = \"nn\") has no coefficients; see summary() and ",
          "plot(type = \"pdp\").")
  NULL
}

#' @export
logLik.rem_nn_fit <- function(object, ...) {
  structure(object$logLik, df = object$n_par, nobs = object$n_strata,
            class = "logLik")
}

#' @export
predict.rem_nn_fit <- function(object, newdata, ...) {
  miss <- setdiff(object$features, names(newdata))
  if (length(miss)) stop("newdata is missing feature column(s): ",
                         paste(miss, collapse = ", "))
  X <- as.matrix(newdata[, object$features, drop = FALSE])
  storage.mode(X) <- "double"
  if (!is.null(object$scaler)) {
    X <- sweep(sweep(X, 2L, object$scaler$mean, "-"), 2L, object$scaler$sd, "/")
  }
  .nn_forward(object$layers, X, object$activation)$scores
}

#' @export
plot.rem_nn_fit <- function(x, type = c("loss", "pdp"), n_grid = 50L, ...) {
  type <- match.arg(type)
  if (type == "loss") {
    h <- x$history
    plot(h$epoch, h$train, type = "l", xlab = "epoch", ylab = "loss",
         main = "Training history", ...)
    if (any(!is.na(h$val))) {
      graphics::lines(h$epoch, h$val, lty = 2)
      graphics::legend("topright", c("train", "validation"), lty = c(1, 2), bty = "n")
    }
  } else {
    p <- length(x$features)
    old <- graphics::par(mfrow = grDevices::n2mfrow(p)); on.exit(graphics::par(old))
    mu <- if (is.null(x$scaler)) rep(0, p) else x$scaler$mean
    for (j in seq_len(p)) {
      sdj <- if (is.null(x$scaler)) 1 else x$scaler$sd[j]
      grid <- seq(mu[j] - 2 * sdj, mu[j] + 2 * sdj, length.out = n_grid)
      nd <- as.data.frame(matrix(rep(mu, each = n_grid), n_grid, p,
                                 dimnames = list(NULL, x$features)))
      nd[[x$features[j]]] <- grid
      plot(grid, stats::predict(x, nd), type = "l", xlab = x$features[j],
           ylab = "partial score", main = x$features[j], ...)
    }
  }
  invisible(x)
}
