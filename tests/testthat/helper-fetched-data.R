# The classroom, Social Evolution, CollegeMsg and Email-EU-core logs are not
# shipped with amorem (their sources state no licence); fetch_dataset()
# downloads them. Each name below is an active binding: a test that uses one
# downloads it once per session, and is skipped on CRAN or when the download
# fails, while tests that do not use it run as usual.
local({
  cache <- file.path(tempdir(), "amorem-fetched")
  env <- parent.frame(2)
  for (nm in c("classroom_events", "classroom_actors", "social_evolution_calls",
               "social_evolution_actors", "social_evolution_friendship",
               "college_msg", "email_eu_core")) {
    local({
      name <- nm
      makeActiveBinding(name, function() {
        testthat::skip_on_cran()
        tryCatch(fetch_dataset(name, cache_dir = cache),
                 error = function(e) testthat::skip(paste("cannot download", name)))
      }, env)
    })
  }
})
