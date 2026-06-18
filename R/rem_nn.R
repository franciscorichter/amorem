#' Control parameters for the neural-network backend of rem()
#'
#' Collects the architecture and training hyper-parameters used by
#' `rem(method = "nn")`. Training maximizes the same conditional-logistic
#' partial likelihood as `method = "clogit"` (softmax over each risk set), so
#' this backend is a drop-in flexible counterpart of the linear conditional
#' logit. Two predictor architectures are available:
#' \describe{
#'   \item{`"mlp"`}{a multilayer perceptron scoring the full covariate vector
#'     jointly — can represent interactions between statistics.}
#'   \item{`"additive_spline"`}{an additive predictor `sum_k f_k(x_k)` with
#'     each `f_k` a B-spline expansion fitted by (mini-batch) stochastic
#'     gradient — the STREAM construction of Filippi-Mazzola & Wit (2024,
#'     JRSS-C 73(4), \doi{10.1093/jrsssc/qlae023}). Interpretable per-feature
#'     curves; with `batch_strata` it scales to event logs far beyond what an
#'     in-memory smooth fit can hold.}
#' }
#'
#' @param hidden Integer vector of hidden-layer sizes for `"mlp"`, e.g.
#'   `c(16, 8)`. Use `integer(0)` for no hidden layer (recovers a linear
#'   conditional logit fit by gradient descent). Ignored for
#'   `"additive_spline"`.
#' @param activation Hidden-layer activation for `"mlp"`: `"relu"` or
#'   `"tanh"`.
#' @param architecture Predictor architecture: `"mlp"` (default) or
#'   `"additive_spline"`; see *Description*.
#' @param spline_df Degrees of freedom (basis size) per covariate for
#'   `"additive_spline"`; passed to [splines::bs()].
#' @param batch_strata Optional mini-batch size, in **strata**, for stochastic
#'   gradient training. `NULL` (default) trains full-batch; a value such as
#'   `512` takes one Adam step per sampled chunk of strata each epoch.
#' @param epochs Maximum number of training epochs (full passes over the
#'   training strata).
#' @param lr Adam learning rate.
#' @param l2 L2 penalty (weight decay) on the weights (not the biases).
#' @param validation Fraction of strata held out for validation / early
#'   stopping. Set to `0` to train on everything (no early stopping).
#' @param patience Early-stopping patience: training stops after this many
#'   epochs without improvement of the validation loss; the best parameters
#'   are restored.
#' @param standardize Z-score the features before training (recommended; the
#'   scaling is stored and re-applied by `predict()`).
#' @param engine Training engine: `"r"` (default) uses the built-in pure-R
#'   implementation with hand-derived gradients; `"torch"` trains the *same*
#'   model and loss with the \pkg{torch} package (libtorch / autograd), which is
#'   markedly faster and, with `batch_strata`, scales to large event logs
#'   (optionally on GPU). The two engines fit identical model classes and return
#'   interchangeable objects. `"torch"` requires the suggested \pkg{torch}
#'   package (run `torch::install_torch()` once) and equal-sized strata (the
#'   usual case-control layout with a fixed number of controls).
#' @param seed Optional integer seed for reproducible initialization and
#'   validation split.
#' @param verbose Print the loss every 50 epochs.
#'
#' @return A list of class `"nn_control"`.
#' @seealso [rem()]
#' @export
nn_control <- function(hidden = c(16L, 8L), activation = c("relu", "tanh"),
                       architecture = c("mlp", "additive_spline"),
                       spline_df = 8L, batch_strata = NULL,
                       epochs = 300L, lr = 1e-2, l2 = 1e-4,
                       validation = 0.2, patience = 25L,
                       standardize = TRUE, engine = c("r", "torch"),
                       seed = NULL, verbose = FALSE) {
  activation <- match.arg(activation)
  architecture <- match.arg(architecture)
  engine <- match.arg(engine)
  hidden <- as.integer(hidden)
  if (any(hidden < 1L)) stop("`hidden` layer sizes must be positive integers.")
  if (lr <= 0) stop("`lr` must be positive.")
  if (validation < 0 || validation >= 1) stop("`validation` must be in [0, 1).")
  spline_df <- as.integer(spline_df)
  if (architecture == "additive_spline" && spline_df < 4L) {
    stop("`spline_df` must be at least 4 for the additive_spline architecture.")
  }
  if (!is.null(batch_strata)) {
    batch_strata <- as.integer(batch_strata)
    if (batch_strata < 2L) stop("`batch_strata` must be at least 2 (or NULL).")
  }
  structure(list(hidden = hidden, activation = activation,
                 architecture = architecture, spline_df = spline_df,
                 batch_strata = batch_strata,
                 epochs = as.integer(epochs), lr = lr, l2 = l2,
                 validation = validation, patience = as.integer(patience),
                 standardize = isTRUE(standardize), engine = engine, seed = seed,
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

# ---- additive-spline expansion (the STREAM construction) ------------------
# A B-spline basis per feature; a linear layer over the concatenated bases is
# exactly an additive spline model sum_k f_k(x_k), trained on the same
# risk-set softmax partial likelihood (Filippi-Mazzola & Wit 2024, JRSS-C).

.nn_spline_expand <- function(X, df) {
  metas <- vector("list", ncol(X)); blocks <- vector("list", ncol(X))
  for (j in seq_len(ncol(X))) {
    b <- splines::bs(X[, j], df = df)
    metas[[j]] <- list(knots = attr(b, "knots"),
                       Boundary.knots = attr(b, "Boundary.knots"),
                       degree = attr(b, "degree"),
                       intercept = attr(b, "intercept"))
    blocks[[j]] <- unclass(b)
  }
  list(X = do.call(cbind, blocks), meta = metas, df = df)
}

.nn_spline_apply <- function(X, expansion) {
  blocks <- lapply(seq_len(ncol(X)), function(j) {
    m <- expansion$meta[[j]]
    suppressWarnings(unclass(splines::bs(
      X[, j], knots = m$knots, Boundary.knots = m$Boundary.knots,
      degree = m$degree, intercept = m$intercept)))
  })
  do.call(cbind, blocks)
}

# ---- torch training engine (optional; requires the suggested 'torch' pkg) --
# Trains the SAME model class and conditional-logistic loss as the pure-R engine
# with libtorch autograd + Adam and mini-batching over strata, then exports the
# learned weights into the R `layers` format so predict()/plot()/logLik() reuse
# the pure-R machinery unchanged. Requires equal-sized strata (the [K, m]
# cross-entropy layout): the usual case-control table with a fixed n_controls.
.nn_train_torch <- function(Xfit, strat_id, is_event, hidden, control,
                            tr, in_val, tr_strata, val_strata) {
  if (!requireNamespace("torch", quietly = TRUE)) {
    stop("nn_control(engine = \"torch\") needs the 'torch' package: ",
         "install.packages(\"torch\") then torch::install_torch().", call. = FALSE)
  }
  if (!torch::torch_is_installed()) {
    stop("libtorch is not installed; run torch::install_torch() once.", call. = FALSE)
  }
  if (!is.null(control$seed)) torch::torch_manual_seed(control$seed)

  # rows -> (feature tensor reshaped per stratum, target = within-stratum event)
  prep <- function(rows) {
    sid <- strat_id[rows]; ord <- order(sid)
    rows <- rows[ord]; sid <- sid[ord]
    sizes <- tabulate(match(sid, unique(sid)))
    if (length(unique(sizes)) != 1L) {
      stop("nn_control(engine = \"torch\") requires equal-sized strata; found ",
           "sizes ", paste(sort(unique(sizes)), collapse = "/"),
           ". Use engine = \"r\" for variable-sized strata.", call. = FALSE)
    }
    m <- sizes[1L]; K <- length(rows) %/% m
    target <- ((which(is_event[rows]) - 1L) %% m) + 1L     # 1-based event column
    list(Xt = torch::torch_tensor(Xfit[rows, , drop = FALSE],
                                  dtype = torch::torch_float()),
         target = torch::torch_tensor(as.integer(target), dtype = torch::torch_long()),
         K = K, m = m)
  }

  # model: linear (+ activation) stack ending in a scalar score
  sizes <- c(ncol(Xfit), hidden, 1L)
  act_fn <- if (control$activation == "relu") torch::nn_relu else torch::nn_tanh
  mods <- list()
  for (l in seq_len(length(sizes) - 1L)) {
    mods[[length(mods) + 1L]] <- torch::nn_linear(sizes[l], sizes[l + 1L])
    if (l < length(sizes) - 1L) mods[[length(mods) + 1L]] <- act_fn()
  }
  model <- do.call(torch::nn_sequential, mods)
  lin_mods <- Filter(function(mo) inherits(mo, "nn_linear"), mods)

  # Adam with weight decay on weights only (matches the R engine's W-only L2)
  pn <- names(model$parameters)
  wts <- pn[grepl("weight", pn)]; bis <- setdiff(pn, wts)
  optim <- torch::optim_adam(list(
    list(params = lapply(wts, function(n) model$parameters[[n]]), weight_decay = control$l2),
    list(params = lapply(bis, function(n) model$parameters[[n]]), weight_decay = 0)),
    lr = control$lr)

  loss_on <- function(d) torch::nnf_cross_entropy(
    model(d$Xt)$reshape(c(d$K, d$m)), d$target)

  full_tr <- prep(which(tr))
  vd <- if (length(val_strata)) prep(which(in_val)) else NULL

  history <- data.frame(epoch = integer(0), train = numeric(0), val = numeric(0))
  best <- list(loss = Inf, state = NULL, epoch = 0L); stall <- 0L
  for (t in seq_len(control$epochs)) {
    if (is.null(control$batch_strata)) {
      batches <- list(full_tr)
    } else {
      sh <- sample(tr_strata)
      chunks <- split(sh, ceiling(seq_along(sh) / control$batch_strata))
      batches <- lapply(chunks, function(ss) prep(which(strat_id %in% ss)))
    }
    tl <- 0
    for (b in batches) {
      optim$zero_grad(); l <- loss_on(b); l$backward(); optim$step()
      tl <- tl + as.numeric(l$item()) * b$K
    }
    train_loss <- tl / full_tr$K
    val_loss <- NA_real_
    if (!is.null(vd)) {
      val_loss <- as.numeric(torch::with_no_grad(loss_on(vd))$item())
      if (val_loss < best$loss - 1e-6) {
        best <- list(loss = val_loss,
                     state = lapply(model$state_dict(), function(z) z$clone()),
                     epoch = t); stall <- 0L
      } else { stall <- stall + 1L; if (stall >= control$patience) break }
    }
    history <- rbind(history, data.frame(epoch = t, train = train_loss, val = val_loss))
    if (control$verbose && t %% 50L == 0L)
      cat(sprintf("epoch %4d  train %.4f  val %s\n", t, train_loss,
                  ifelse(is.na(val_loss), "-", sprintf("%.4f", val_loss))))
  }
  if (!is.null(best$state)) model$load_state_dict(best$state)

  # export torch linear layers -> R `layers` (W: [nin,nout], b: [nout])
  layers <- lapply(lin_mods, function(mo) list(
    W = t(as.matrix(torch::as_array(mo$weight))),
    b = as.numeric(torch::as_array(mo$bias))))
  list(layers = layers, history = history,
       best_epoch = if (!is.null(best$state)) best$epoch else nrow(history))
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

  # architecture: joint MLP on X, or linear layer over per-feature B-splines
  expansion <- NULL
  if (control$architecture == "additive_spline") {
    ex <- .nn_spline_expand(X, control$spline_df)
    Xfit <- ex$X; expansion <- ex; hidden <- integer(0)
  } else {
    Xfit <- X; hidden <- control$hidden
  }

  if (!is.null(control$seed)) set.seed(control$seed)
  strata <- unique(strat_id)
  val_strata <- integer(0)
  if (control$validation > 0 && length(strata) >= 10L) {
    val_strata <- sample(strata, max(1L, floor(control$validation * length(strata))))
  }
  in_val <- strat_id %in% val_strata
  tr <- !in_val
  tr_strata <- setdiff(strata, val_strata)

  if (identical(control$engine, "torch")) {
    tt <- .nn_train_torch(Xfit, strat_id, is_event, hidden, control,
                          tr = tr, in_val = in_val,
                          tr_strata = tr_strata, val_strata = val_strata)
    layers <- tt$layers; history <- tt$history; best <- list(epoch = tt$best_epoch)
  } else {
  layers <- .nn_init(ncol(Xfit), hidden, seed = control$seed)
  state <- lapply(layers, function(ly) list(
    W = list(m = ly$W * 0, v = ly$W * 0), b = list(m = ly$b * 0, v = ly$b * 0)))

  history <- data.frame(epoch = integer(0), train = numeric(0), val = numeric(0))
  best <- list(loss = Inf, layers = layers, epoch = 0L)
  stall <- 0L; step <- 0L
  for (t in seq_len(control$epochs)) {
    if (is.null(control$batch_strata)) {
      batches <- list(which(tr))
    } else {
      sh <- sample(tr_strata)
      chunks <- split(sh, ceiling(seq_along(sh) / control$batch_strata))
      batches <- lapply(chunks, function(ss) which(strat_id %in% ss))
    }
    ep_loss <- 0; ep_strata <- 0L
    for (rows in batches) {
      step <- step + 1L
      fw <- .nn_forward(layers, Xfit[rows, , drop = FALSE], control$activation)
      lg <- .nn_loss_grad(fw$scores, strat_id[rows], is_event[rows])
      grads <- .nn_backward(layers, fw$acts, lg$grad, control$activation, control$l2)
      upd <- .nn_adam_step(layers, grads, state, control$lr, step)
      layers <- upd$layers; state <- upd$state
      nb <- length(unique(strat_id[rows]))
      ep_loss <- ep_loss + lg$loss * nb; ep_strata <- ep_strata + nb
    }
    train_loss <- ep_loss / max(ep_strata, 1L)

    val_loss <- NA_real_
    if (length(val_strata)) {
      fv <- .nn_forward(layers, Xfit[in_val, , drop = FALSE], control$activation)
      val_loss <- .nn_loss_grad(fv$scores, strat_id[in_val], is_event[in_val])$loss
      if (val_loss < best$loss - 1e-6) {
        best <- list(loss = val_loss, layers = layers, epoch = t); stall <- 0L
      } else {
        stall <- stall + 1L
        if (stall >= control$patience) break
      }
    }
    history <- rbind(history, data.frame(epoch = t, train = train_loss, val = val_loss))
    if (control$verbose && t %% 50L == 0L) {
      cat(sprintf("epoch %4d  train %.4f  val %s\n", t, train_loss,
                  ifelse(is.na(val_loss), "-", sprintf("%.4f", val_loss))))
    }
  }
  if (length(val_strata)) layers <- best$layers
  }

  # final pass over everything: log-likelihood, validation concordance
  fa <- .nn_forward(layers, Xfit, control$activation)
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
    expansion = expansion, features = feature_names, control = control,
    history = history,
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
  if (!is.null(x$expansion)) {
    cat("  architecture : additive B-splines (df = ", x$expansion$df,
        " per feature, ", length(x$features), " features)\n", sep = "")
  } else {
    cat("  architecture : ", paste(c(length(x$features), x$control$hidden, 1L),
                                   collapse = " - "),
        "  (", x$activation, ")\n", sep = "")
  }
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
  if (!is.null(object$expansion)) X <- .nn_spline_apply(X, object$expansion)
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
