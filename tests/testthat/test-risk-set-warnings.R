# Events without controls, repeated dyads under risk = "remove", and the class
# of rem() fits.

test_that("events with no valid control are reported in a warning and an attribute", {
  el <- data.frame(sender = c("A", "A"), receiver = c("B", "B"), time = c(1, 2))
  expect_warning(
    cc <- sample_non_events(el, n_controls = 1,
                            exclude_pairs = data.frame(sender = "B", receiver = "A"),
                            seed = 1),
    "2 of 2 event")
  expect_equal(sum(cc$event == 0L), 0L)
  expect_equal(attr(cc, "no_control"), 1:2)
})

test_that("a sample where every event has a control gives no warning and an empty attribute", {
  data(classroom_events, package = "amorem", envir = environment())
  expect_no_warning(cc <- sample_non_events(head(classroom_events, 50), seed = 1))
  expect_length(attr(cc, "no_control"), 0L)
})

test_that("scope = 'appearance' does not warn about the first event", {
  set.seed(4)
  el <- data.frame(sender   = sample(letters[1:8], 60, replace = TRUE),
                   receiver = sample(letters[1:8], 60, replace = TRUE),
                   time     = sort(runif(60)), stringsAsFactors = FALSE)
  el <- el[el$sender != el$receiver, ]
  expect_no_warning(cc <- sample_non_events(el, scope = "appearance", seed = 2))
  expect_true(1L %in% attr(cc, "no_control"))
})

test_that("time-shifted sampling exposes its uninformative strata as no_control", {
  data(classroom_events, package = "amorem", envir = environment())
  cc <- sample_non_events(head(classroom_events, 80), shift = "exponential",
                          shift_scale = 3, seed = 1)
  expect_identical(attr(cc, "no_control"), attr(cc, "shift")$uninformative)
})

test_that("risk = 'remove' warns when a dyad fires more than once", {
  el <- data.frame(sender = c("A", "A", "C"), receiver = c("B", "B", "A"),
                   time = c(1, 2, 3))
  expect_warning(sample_non_events(el, risk = "remove", seed = 1),
                 "1 dyad\\(s\\) fire more than once \\(e.g. A->B\\)")
  expect_warning(sample_non_events(el, risk = "remove", shift = "exponential",
                                   seed = 1),
                 "fire more than once")
  # recurrent events are what risk = "standard" is for
  expect_no_warning(sample_non_events(el, risk = "standard", seed = 1))
  # each dyad once: no warning
  el1 <- data.frame(sender = c("A", "B", "C"), receiver = c("B", "C", "A"),
                    time = c(1, 2, 3))
  expect_no_warning(sample_non_events(el1, risk = "remove", seed = 1))
})

test_that("rem() fits have class 'amorem_rem', not 'rem'", {
  set.seed(1)
  d <- data.frame(stratum = rep(1:60, each = 2), event = rep(c(1, 0), 60),
                  x = rnorm(120))
  d$x[d$event == 1] <- d$x[d$event == 1] + 1
  fit <- rem(event ~ x, data = d, method = "clogit")
  expect_s3_class(fit, "amorem_rem")
  expect_false(inherits(fit, "rem"))
  # a method another package registers on class "rem" never reaches the fit
  registerS3method("print", "rem", function(x, ...) cat("foreign method\n"),
                   envir = asNamespace("base"))
  on.exit(rm(list = "print.rem", envir = get(".__S3MethodsTable__.",
                                             envir = asNamespace("base"))))
  expect_output(print(fit), "Relational event model")
  expect_false(any(grepl("foreign", capture.output(print(fit)))))
})
