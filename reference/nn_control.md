# Control parameters for the neural-network backend of rem()

Collects the architecture and training hyper-parameters used by
`rem(method = "nn")`. The network is a multilayer perceptron scoring
each candidate in a case-control stratum; training maximizes the same
conditional-logistic partial likelihood as `method = "clogit"` (softmax
over each risk set), so the neural backend is a drop-in nonlinear
counterpart of the linear conditional logit.

## Usage

``` r
nn_control(
  hidden = c(16L, 8L),
  activation = c("relu", "tanh"),
  epochs = 300L,
  lr = 0.01,
  l2 = 1e-04,
  validation = 0.2,
  patience = 25L,
  standardize = TRUE,
  seed = NULL,
  verbose = FALSE
)
```

## Arguments

- hidden:

  Integer vector of hidden-layer sizes, e.g. `c(16, 8)`. Use
  `integer(0)` for no hidden layer (recovers a linear conditional logit
  fit by gradient descent).

- activation:

  Hidden-layer activation: `"relu"` or `"tanh"`.

- epochs:

  Maximum number of full-batch training epochs.

- lr:

  Adam learning rate.

- l2:

  L2 penalty (weight decay) on the weights (not the biases).

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

- seed:

  Optional integer seed for reproducible initialization and validation
  split.

- verbose:

  Print the loss every 50 epochs.

## Value

A list of class `"nn_control"`.

## See also

[`rem()`](https://franciscorichter.github.io/amore/reference/rem.md)
