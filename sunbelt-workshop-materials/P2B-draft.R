library(amore)
library(mgcViz)
library(RColorBrewer)
library(dplyr)
options(warn = -1)

load("input/AYNTK.RData")

# P1.1: What does the generated data look like? ####

head(dat_gam[, c("SOURCE_ev", "TARGET_ev", "TIME_ev")])

# set of authors
dat_gam[481, "SOURCE_ev"]
# author set size
dat_gam[481, "source.size_ev"]
# set of cited papers
dat_gam[481, "TARGET_ev"]
# cited papers set size
dat_gam[481, "target.size_ev"]

head(dat_gam[, c("SOURCE_nv", "TARGET_nv", "TIME_nv")])


# P1.2: Covariate and attribute computation ####

ncc_data <- dat_gam[,c("TIME_ev", "transformed_time",
                       "author.sub.rep.1_ev", "author.sub.rep.1_nv",
                       "diff.author.publication.activity_ev", "diff.author.publication.activity_nv",
                       "transform_diff.author.publication.activity_ev", "transform_diff.author.publication.activity_nv",
                       "paper.outdegree.popularity_ev", "paper.outdegree.popularity_nv",
                       "reference.sub.rep.1_ev", "reference.sub.rep.1_nv")]

head(ncc_data)




# P1.3: Linearity first ####

gam_linear <- rem(~ diff.author.publication.activity +
                    paper.outdegree.popularity +
                    author.sub.rep.1 +
                    reference.sub.rep.1,
                  method = "gam",
                  data = ncc_data)

## -----------------------------------------------------------------------------
summary(gam_linear)


# P1.4: Beyond linearity ####

## Time-varying effect ####

gam_tve <- rem(~ tv(diff.author.publication.activity) +
                 paper.outdegree.popularity +
                 author.sub.rep.1 +
                 reference.sub.rep.1,
               method ="gam", time = "TIME_ev",
               data = ncc_data)

## -----------------------------------------------------------------------------
summary(gam_tve)

## -----------------------------------------------------------------------------
plot(gam_tve)


gam_tve_transform <- rem(~ tv(diff.author.publication.activity) +
                           paper.outdegree.popularity +
                           author.sub.rep.1 +
                           reference.sub.rep.1,
               method ="gam", time = "transformed_time",
               data = ncc_data)

## -----------------------------------------------------------------------------
summary(gam_tve_transform)

## -----------------------------------------------------------------------------
plot(gam_tve_transform)


## Non-linear effect ####

gam_nle <- rem(~ nl(diff.author.publication.activity) + ## automatically uses the transformed one
                 paper.outdegree.popularity +
                 author.sub.rep.1 +
                 reference.sub.rep.1,
               method ="gam",
               data = ncc_data)

## -----------------------------------------------------------------------------
summary(gam_nle)

## -----------------------------------------------------------------------------
plot(gam_nle)

## Time-varying non-linear effect ####

gam_tvnle <- rem(~ tvnl(diff.author.publication.activity) + ## automatically uses the transformed one
                   paper.outdegree.popularity +
                   author.sub.rep.1 +
                   reference.sub.rep.1,
                 method="gam", time = "transformed_time",
                 data = ncc_data)

viz <- getViz(gam_tvnle$fit) ## small inconstincency in rem output
# when fitting a tvnl effect: the output is not directly a gam object as it is for the other cases
# the gam object is 

## -----------------------------------------------------------------------------
summary(gam_tvnle$fit)

## -----------------------------------------------------------------------------
plot_obj <- plot(viz)
plot_data <- plot_obj$plots[[1]]$ggObj$data
plot_data <- plot_data[!is.na(plot_data$z),]
plot_data <- plot_data %>%
  group_by(x) %>%
  mutate(z_centered = z - mean(z)) %>%
  ungroup()
ggplot(plot_data, aes(x = x, y = y, fill = z_centered)) +
  geom_tile() +
  geom_contour(mapping = aes(x = x, y = y, z = z_centered, group = 1), 
               color = "black", inherit.aes = FALSE) +
  scale_fill_viridis_c()
