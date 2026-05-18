# test-hyperedge-features.R
# Coverage for compute_hyperedge_features(): hyperedge-native subrep /
# activity stats + delegation to the dyadic 68-stat catalogue.

fixture <- function() {
  hyperedge_log(
    I    = list(c("a","b"), c("a","b","c"), c("a","c"), c("b","c","d")),
    J    = list(c("X"),     c("X","Y"),     c("Y"),     c("X","Y","Z")),
    time = c(1, 2, 3, 4))
}

test_that("activity stat matches hyperedge_activity()", {
  hl <- fixture()
  feat <- compute_hyperedge_features(hl, stats = "activity")
  expect_true("activity" %in% names(feat))
  # First row has no prior events -> 0.
  expect_equal(feat$activity[1], 0)
  # Second row (I = {a,b,c}, J = {X,Y}, t = 2): one prior event (t = 1)
  # with I_1 = {a, b}. {a,b,c} subset of {a,b}? no. So 0.
  expect_equal(feat$activity[2], 0)
})

test_that("subrep family is invoked with correct (rho, l)", {
  hl <- fixture()
  feat <- compute_hyperedge_features(hl,
            stats = c("subrep_1_1", "subrep_2_1"))
  # On row 4 (I = {b, c, d}, J = {X, Y, Z}, t = 4):
  # subrep_1_1 averages activity over individual-sender × individual-receiver.
  manual <- hyperedge_subrep(hl,
                              I = hl$I[[4]], J = hl$J[[4]], t = hl$time[4],
                              rho = 1, l = 1)
  expect_equal(feat$subrep_1_1[4], manual)
})

test_that("subrep_<rho> (no underscore l) defaults to receiver-agnostic", {
  hl <- fixture()
  feat <- compute_hyperedge_features(hl, stats = "subrep_1")
  # subrep_1 means rho = 1, l = 0: receiver-side ignored.
  manual <- hyperedge_subrep(hl,
                              I = hl$I[[4]], J = hl$J[[4]], t = hl$time[4],
                              rho = 1, l = 0)
  expect_equal(feat$subrep_1[4], manual)
})

test_that("delegating dyadic stats works when every event is dyadic", {
  hl <- hyperedge_log(
    I    = list("a", "b", "a", "a"),
    J    = list("b", "a", "b", "c"),
    time = c(1, 2, 3, 4))
  feat <- compute_hyperedge_features(hl,
            stats = c("reciprocity_count", "subrep_1_1"))
  expect_true("reciprocity_count" %in% names(feat))
  # reciprocity_count counts REVERSE-direction past events:
  #   r=a (t=1): past b->a = 0; r=b (t=2): past a->b = 1;
  #   r=a (t=3): past b->a = 1; r=c (t=4): past c->a = 0.
  expect_equal(feat$reciprocity_count, c(0, 1, 1, 0))
  # subrep_1_1 on a dyadic log counts SAME-direction past events:
  #   (a,b) t=1: 0; (b,a) t=2: 0; (a,b) t=3: 1 (row 1); (a,c) t=4: 0.
  expect_equal(feat$subrep_1_1, c(0, 0, 1, 0))
})

test_that("dyadic stat on non-dyadic hyperedge log errors out", {
  hl <- fixture()  # contains rows with |I| > 1
  expect_error(
    compute_hyperedge_features(hl, stats = "reciprocity_count"),
    "non-dyadic")
})

test_that("requested (rho, l) larger than focal row produces NA", {
  hl <- hyperedge_log(
    I    = list("a"),
    J    = list("b"),
    time = c(1))
  # subrep_2_1 on a singleton-I row is undefined → NA.
  feat <- compute_hyperedge_features(hl, stats = "subrep_2_1")
  expect_true(is.na(feat$subrep_2_1[1]))
})
