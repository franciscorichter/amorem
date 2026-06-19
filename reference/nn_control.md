# Control parameters for the neural-network backend of rem()

Collects the architecture and training hyper-parameters used by
`rem(method = "nn")`. Training maximizes the same conditional-logistic
partial likelihood as `method = "clogit"` (softmax over each risk set),
so this backend is a drop-in flexible counterpart of the linear
conditional logit. Two predictor architectures are available:

- `"mlp"`:

  a multilayer perceptron scoring the full covariate vector jointly —
  can represent interactions between statistics.

- `"additive_spline"`:

  an additive predictor `sum_k f_k(x_k)` with each `f_k` a B-spline
  expansion fitted by (mini-batch) stochastic gradient — the STREAM
  construction of Filippi-Mazzola & Wit (2024, JRSS-C 73(4),
  [doi:10.1093/jrsssc/qlae023](https://doi.org/10.1093/jrsssc/qlae023)
  ). Interpretable per-feature curves; with `batch_strata` it scales to
  event logs far beyond what an in-memory smooth fit can hold.

## Usage

``` r
nn_control(
  hidden = c(16L, 8L),
  activation = c("relu", "tanh"),
  architecture = c("mlp", "additive_spline"),
  spline_df = 8L,
  batch_strata = NULL,
  epochs = 300L,
  lr = 0.01,
  l2 = 1e-04,
  validation = 0.2,
  patience = 25L,
  standardize = TRUE,
  engine = c("r", "torch"),
  seed = NULL,
  verbose = FALSE
)
```

## Arguments

- hidden:

  Integer vector of hidden-layer sizes for `"mlp"`, e.g. `c(16, 8)`. Use
  `integer(0)` for no hidden layer (recovers a linear conditional logit
  fit by gradient descent). Ignored for `"additive_spline"`.

- activation:

  Hidden-layer activation for `"mlp"`: `"relu"` or `"tanh"`.

- architecture:

  Predictor architecture: `"mlp"` (default) or `"additive_spline"`; see
  *Description*.

- spline_df:

  Degrees of freedom (basis size) per covariate for `"additive_spline"`;
  passed to [`splines::bs()`](https://rdrr.io/r/splines/bs.html).

- batch_strata:

  Optional mini-batch size, in **strata**, for stochastic gradient
  training. `NULL` (default) trains full-batch; a value such as `512`
  takes one Adam step per sampled chunk of strata each epoch.

- epochs:

  Maximum number of training epochs (full passes over the training
  strata).

- lr:

  Adam learning rate.

- l2:

  L2 penalty (weight decay). The pure-R engine penalises the weights
  only; the torch engine applies it via Adam's `weight_decay`.

- validation:

  Fraction of strata held out for validation / early stopping. Set to
  `0` to train on everything (no early stopping).

- patience:

  Early-stopping patience: training stops after this many epochs without
  improvement of the validation loss; the best parameters are restored.

- standardize:

  Z-score the features before training (recommended; the scaling is
  stored and re-applied by
  [`predict()`](https://rdrr.io/r/stats/predict.html)).

- engine:

  Training engine: `"r"` (default) uses the built-in pure-R
  implementation with hand-derived gradients; `"torch"` trains the
  *same* model and loss with the torch package (libtorch / autograd),
  which is markedly faster and, with `batch_strata`, scales to large
  event logs (optionally on GPU). The two engines fit identical model
  classes and return interchangeable objects. `"torch"` requires the
  suggested torch package (run
  [`torch::install_torch()`](https://torch.mlverse.org/docs/reference/install_torch.html)
  once) and equal-sized strata (the usual case-control layout with a
  fixed number of controls).

- seed:

  Optional integer seed for reproducible initialization and validation
  split.

- verbose:

  Print the loss every 50 epochs.

## Value

A list of class `"nn_control"`.

## See also

[`rem()`](https://franciscorichter.github.io/amorem/reference/rem.md)
