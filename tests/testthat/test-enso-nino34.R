# test-enso-nino34.R
# The bundled ENSO reconstruction (Li et al. 2013) and its use as a global
# covariate.

test_that("enso_nino34 loads with one value per year, 1301-2005", {
  data(enso_nino34, envir = environment())
  expect_s3_class(enso_nino34, "data.frame")
  expect_named(enso_nino34, c("year", "nino34"))
  expect_identical(enso_nino34$year, 1301:2005)
  expect_type(enso_nino34$nino34, "double")
  expect_false(anyNA(enso_nino34$nino34))
})

test_that("enso_nino34 matches the shipped NOAA file", {
  path <- system.file("extdata", "enso_nino34", "enso-li2013.txt",
                      package = "amorem")
  skip_if(!nzchar(path), "raw NOAA file not installed")
  raw <- utils::read.delim(path, comment.char = "#", fileEncoding = "UTF-8-BOM")
  data(enso_nino34, envir = environment())
  expect_identical(as.integer(raw$age_AD), enso_nino34$year)
  expect_identical(as.numeric(raw$sst.anom), enso_nino34$nino34)
})

test_that("enso_nino34 drives the simulator as a global covariate", {
  data(enso_nino34, envir = environment())
  e <- enso_nino34[enso_nino34$year >= 1900, ]
  g <- data.frame(time_start = e$year, nino34 = e$nino34)
  set.seed(1)
  a <- paste0("a", 1:5)
  ev <- simulate_relational_events(n_events = 50, senders = a, receivers = a,
                                   baseline_rate = 0.05, start_time = 1900,
                                   horizon = 2005, global_covariates = g,
                                   global_effects = c(nino34 = 0.5))
  expect_true(all(ev$time >= 1900 & ev$time <= 2005))
  expect_equal(ev$nino34, g$nino34[findInterval(ev$time, g$time_start)])
})
