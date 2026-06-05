library(amore)
suppressPackageStartupMessages(library(survival))
library(knitr)
load("input/AYNTK.RData")

# P1.1: What does the generated data look like? ####

tab1 <- head(dat_gam[, c("SOURCE_ev", "TARGET_ev", "TIME_ev")])
kable(tab1, format = "latex", booktabs = TRUE)

# set of authors
dat_gam[481, "SOURCE_ev"]
# author set size
dat_gam[481, "source.size_ev"]
# set of cited papers
dat_gam[481, "TARGET_ev"]
# cited papers set size
dat_gam[481, "target.size_ev"]

tab2 <- head(dat_gam[, c("SOURCE_nv", "TARGET_nv", "TIME_nv")])
kable(tab2, format = "latex", booktabs = TRUE)

# P1.2: Covariate and attribute computation ####

ncc_data <- data.frame(
  d_author.sub.rep.1 = 
    dat_gam$author.sub.rep.1_ev - 
    dat_gam$author.sub.rep.1_nv,
  d_diff.author.publication.activity = 
    dat_gam$diff.author.publication.activity_ev - 
    dat_gam$diff.author.publication.activity_nv,
  d_paper.outdegree.popularity = 
    dat_gam$paper.outdegree.popularity_ev -
    dat_gam$paper.outdegree.popularity_nv,
  d_reference.sub.rep.1 = 
    dat_gam$reference.sub.rep.1_ev - 
    dat_gam$reference.sub.rep.1_nv,
  one = 1
)
tab3 <- head(ncc_data)
kable(tab3, format = "latex", booktabs = TRUE)

# P1.3: Beyond linearity ####

## Time-varying effect ####

gam_tve <- gam(y ~ -1 + s(TIME_ev, by=diff.author.publication.activity) +
                 paper.outdegree.popularity +
                 author.sub.rep.1 +
                 reference.sub.rep.1,
               family="binomial",
               data = dat_gam)

## Non-linear effect ####

diff.author.publication.activity_matrix <-
  cbind(dat_gam$transform_diff.author.publication.activity_ev,
        dat_gam$transform_diff.author.publication.activity_nv)
W <- diff.author.publication.activity_matrix
W[,1] <- 1
W[,2] <- -1
gam_nle <- gam(y ~ -1 + s(diff.author.publication.activity_matrix, by=W) +
                 paper.outdegree.popularity +
                 author.sub.rep.1 +
                 reference.sub.rep.1,
               family="binomial",
               data = dat_gam)

## Time-varying non-linear effect ####

time_matrix <-
  cbind(dat_gam$transformed_time,
        dat_gam$transformed_time)
gam_tvnle <- gam(y ~ -1 + te(time_matrix, diff.author.publication.activity_matrix, by=W) +
                   paper.outdegree.popularity +
                   author.sub.rep.1 +
                   reference.sub.rep.1,
                 family="binomial",
                 data = dat_gam)
