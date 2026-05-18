# test-subset-repetition.R
# Coverage for hyperedge_activity() and hyperedge_subrep()
# (Boschi, Lerner & Wit 2025).

build_fixture <- function() {
  hyperedge_log(
    I    = list(c("a","b"), c("a","b","c"), c("a","c"), c("b","c","d")),
    J    = list(c("X"),     c("X","Y"),     c("Y"),     c("X","Y","Z")),
    time = c(1, 2, 3, 4))
}

test_that("hyperedge_activity counts the right past events", {
  hl <- build_fixture()
  # Activity for I = {a}, J = {} before t = 5: every prior event
  # that includes 'a' as a sender. Events 1, 2, 3 do; event 4 does not.
  expect_equal(hyperedge_activity(hl, I = "a", J = character(0), t = 5), 3L)
  # Activity for I = {a, b}, J = {X} before t = 5:
  # event 1 includes I and J -> yes. Event 2 includes I and J -> yes.
  # Event 3 (I = {a, c}) does NOT include {a, b}. Event 4 has {b, c, d}
  # without 'a'. Total = 2.
  expect_equal(hyperedge_activity(hl, I = c("a","b"), J = "X", t = 5), 2L)
})

test_that("hyperedge_activity respects the strictly-before-t filter", {
  hl <- build_fixture()
  expect_equal(hyperedge_activity(hl, I = "a", J = character(0), t = 1), 0L)
  expect_equal(hyperedge_activity(hl, I = "a", J = character(0), t = 2), 1L)
})

test_that("hyperedge_subrep with rho = l = full equals activity", {
  hl <- build_fixture()
  for (focal_I in list("a", c("a","b"), c("a","b","c"))) {
    a <- hyperedge_activity(hl, I = focal_I, J = "X", t = 5)
    s <- hyperedge_subrep(hl,    I = focal_I, J = "X", t = 5,
                            rho = length(focal_I), l = 1)
    expect_equal(s, a,
                 info = paste("focal_I =", paste(focal_I, collapse = ",")))
  }
})

test_that("hyperedge_subrep averages over subsets correctly", {
  hl <- build_fixture()
  # Focal I = {a, b}, rho = 1: average activity of {a} and {b} on J = "X".
  # activity({a}, X) before 5: events 1, 2, 4 (event 4 includes X? J_4 = {X,Y,Z} yes)
  #   - event 1: I = {a,b} ⊇ {a}? yes, J = {X} ⊇ {X}? yes
  #   - event 2: I = {a,b,c} ⊇ {a}? yes, J = {X,Y} ⊇ {X}? yes
  #   - event 3: I = {a,c} ⊇ {a}? yes, J = {Y} ⊇ {X}? no
  #   - event 4: I = {b,c,d} ⊇ {a}? no
  #   -> 2
  a_a <- hyperedge_activity(hl, I = "a", J = "X", t = 5)
  a_b <- hyperedge_activity(hl, I = "b", J = "X", t = 5)
  expected <- (a_a + a_b) / 2
  expect_equal(
    hyperedge_subrep(hl, I = c("a","b"), J = "X", t = 5, rho = 1, l = 1),
    expected)
})

test_that("on a dyadic hyperedge log, subrep^{1,1} matches the dyad event count", {
  # Build a dyadic-equivalent log:
  hl <- hyperedge_log(
    I    = list("a", "b", "a", "a"),
    J    = list("b", "a", "b", "c"),
    time = c(1, 2, 3, 4))
  # Past events with sender = a, receiver = b before t = 5: events 1 and 3.
  expect_equal(
    hyperedge_subrep(hl, I = "a", J = "b", t = 5, rho = 1, l = 1),
    2)
})

test_that("hyperedge_subrep input validation", {
  hl <- build_fixture()
  expect_error(hyperedge_subrep(hl, I = c("a","b"), J = "X", t = 5, rho = 3),
               "between 1 and length")
  expect_error(hyperedge_subrep(hl, I = c("a","b"), J = "X", t = 5, l = 5),
               "between 0 and length")
  expect_error(hyperedge_subrep(hl, I = character(0), J = "X", t = 5),
               "non-empty")
})
