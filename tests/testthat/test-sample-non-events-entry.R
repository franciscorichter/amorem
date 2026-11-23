# sample_non_events(entry = ): actors can be control senders (receivers)
# only from their entry time on.

toy <- data.frame(
  sender   = c("a", "a", "b", "c", "b", "d", "c"),
  receiver = c("x", "y", "x", "y", "z", "z", "x"),
  time     = c(1, 2, 3, 4, 5, 6, 7),
  stringsAsFactors = FALSE)

test_that("controls use only senders that have entered (entry <= t)", {
  ent <- c(a = 0, b = 3, c = 4, d = 6)
  cc <- sample_non_events(toy, mode = "two", n_controls = 5, seed = 1,
                          entry = ent)
  ctr <- cc[cc$event == 0, ]
  expect_true(all(ent[ctr$sender] <= ctr$time))
  # the entry time itself is included: b is eligible at t = 3
  set.seed(2)
  cc3 <- sample_non_events(toy, mode = "two", n_controls = 50, seed = 3,
                           entry = ent)
  c3 <- cc3[cc3$event == 0 & cc3$time == 3, ]
  expect_true("b" %in% c3$sender)
  expect_false(any(c3$sender %in% c("c", "d")))
})

test_that("entry = NULL gives the same sample as before", {
  a <- sample_non_events(toy, mode = "two", n_controls = 2, seed = 9)
  b <- sample_non_events(toy, mode = "two", n_controls = 2, seed = 9,
                         entry = NULL)
  expect_identical(a, b)
})

test_that("a data.frame of actor and entry time equals the named vector", {
  ent <- c(a = 0, b = 3, c = 4, d = 6)
  df1 <- data.frame(actor = names(ent), entry = unname(ent))
  df2 <- data.frame(species = names(ent), entry = unname(ent))
  v  <- sample_non_events(toy, mode = "two", n_controls = 3, seed = 4,
                          entry = ent)
  expect_identical(sample_non_events(toy, mode = "two", n_controls = 3,
                                     seed = 4, entry = df1), v)
  expect_identical(sample_non_events(toy, mode = "two", n_controls = 3,
                                     seed = 4, entry = df2), v)
})

test_that("list(sender, receiver) restricts both roles", {
  cc <- sample_non_events(toy, mode = "two", n_controls = 20, seed = 5,
                          entry = list(receiver = c(z = 5, y = 2)))
  ctr <- cc[cc$event == 0, ]
  expect_false(any(ctr$receiver == "z" & ctr$time < 5))
  expect_false(any(ctr$receiver == "y" & ctr$time < 2))
  expect_true(any(ctr$receiver == "z" & ctr$time >= 5))
})

test_that("under mode = 'one' the restriction is per role", {
  ent <- c(d = 6)
  cc <- sample_non_events(toy, mode = "one", n_controls = 40, seed = 6,
                          entry = ent)
  ctr <- cc[cc$event == 0, ]
  expect_false(any(ctr$sender == "d" & ctr$time < 6))
  expect_true(any(ctr$receiver == "d" & ctr$time < 6))
  cc2 <- sample_non_events(toy, mode = "one", n_controls = 40, seed = 6,
                           entry = list(sender = ent, receiver = ent))
  c2 <- cc2[cc2$event == 0, ]
  expect_false(any((c2$sender == "d" | c2$receiver == "d") & c2$time < 6))
})

test_that("an event with an empty restricted risk set gets no control", {
  ev <- data.frame(sender = c("a", "a", "b"), receiver = c("x", "y", "x"),
                   time = c(1, 2, 3), stringsAsFactors = FALSE)
  # At t = 2 only a has entered as a sender, (a, x) has fired and (a, y) is
  # the event itself: the risk set is empty. Without `entry`, (b, x) is a
  # control.
  plain <- sample_non_events(ev, mode = "two", risk = "remove", seed = 1)
  expect_length(attr(plain, "no_control"), 0L)
  expect_warning(
    cc <- sample_non_events(ev, mode = "two", risk = "remove", seed = 1,
                            entry = c(a = 0, b = 3)),
    "1 of 3 event\\(s\\) have no valid control")
  expect_identical(attr(cc, "no_control"), 2L)
  expect_false(any(cc$event == 0 & cc$stratum == 2L))
  expect_true(any(cc$event == 0 & cc$stratum == 3L))
})

test_that("entry combines with risk = 'remove', exclude_pairs and n_controls", {
  ent <- c(a = 0, b = 3, c = 4, d = 6)
  excl <- data.frame(sender = "c", receiver = "z")
  cc <- suppressWarnings(
    sample_non_events(toy, mode = "two", risk = "remove", n_controls = 4,
                      seed = 8, entry = ent, exclude_pairs = excl))
  ctr <- cc[cc$event == 0, ]
  expect_true(all(ent[ctr$sender] <= ctr$time))
  expect_false(any(ctr$sender == "c" & ctr$receiver == "z"))
  fired_before <- mapply(function(s, r, t) {
    any(toy$sender == s & toy$receiver == r & toy$time <= t)
  }, ctr$sender, ctr$receiver, ctr$time)
  expect_false(any(fired_before))
  ok <- setdiff(unique(cc$stratum), attr(cc, "no_control"))
  expect_true(all(table(ctr$stratum)[as.character(ok)] == 4L))
})

test_that("entry is validated and refused with shift = 'exponential'", {
  expect_error(sample_non_events(toy, entry = c(1, 2)), "named numeric")
  expect_error(sample_non_events(toy, entry = list(foo = c(a = 1))),
               "sender")
  expect_error(sample_non_events(toy, entry = c(a = NA_real_, b = 1)),
               "missing entry")
  expect_error(sample_non_events(toy, shift = "exponential",
                                 entry = c(a = 1)), "exponential")
  expect_warning(sample_non_events(toy, mode = "two", seed = 1,
                                   entry = c(d = 10)),
                 "before the entry time")
})

test_that("alien_mammals: every first record gets a control from entered species", {
  data(alien_mammals, package = "amorem", envir = environment())
  ev <- alien_mammals[alien_mammals$event == 1, ]
  el <- data.frame(sender = ev$species, receiver = ev$region, time = ev$stop)
  ent <- attr(alien_mammals, "entry")
  cc <- sample_non_events(el, mode = "two", risk = "remove", n_controls = 1,
                          seed = 2005,
                          exclude_pairs = attr(alien_mammals, "never_at_risk"),
                          entry = ent)
  expect_length(attr(cc, "no_control"), 0L)
  ctr <- cc[cc$event == 0, ]
  expect_equal(nrow(ctr), nrow(el))
  e <- stats::setNames(ent$entry, ent$species)
  expect_true(all(e[ctr$sender] <= ctr$time))
})
