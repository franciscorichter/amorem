################################################################################

library(mgcv)
library(RColorBrewer)
load(file="dat_gam_FR_intro_to_rems.RData")

sp1 <- dat.gam$sp1
sp2 <- dat.gam$sp2
sp <- factor(c(sp1,sp2))
dim(sp) <- c(length(sp1),2)

unit <- rep(1, nrow(dat.gam))
I = cbind(unit,-unit)	
gam_sp.only <- gam(y ~ s(sp, by=I, bs="re") - 1,
                   family="binomial"(link = 'logit'), data=dat.gam)

re.species <- coefficients(gam_sp.only)
sort(re.species, decreasing = TRUE)[1:5]
sort(re.species)[1:5]

################################################################################

remotes::install_github("franciscorichter/amore")
library(amore)

# check to understand how data should be structured
# set.seed(1)
# w <- simulate_relational_events(
#   n_events = 300, senders = paste0("a", 1:12), receivers = paste0("a", 1:12),
#   n_controls = 1, endogenous_stats = "reciprocity_count",
#   endogenous_effects = c(reciprocity_count = 0.6), wide = TRUE)
# head(w)

colnames(dat.gam)
dat.gam <- dat.gam[,1:6]
dat.gam$stratum <- 1:nrow(dat.gam)
colnames(dat.gam) <- c("event",
                       "time",
                       "sender_ev",
                       "receiver_ev",
                       "sender_nv",
                       "receiver_nv", 
                       "stratum")
fit <- rem(~ re(sender), data = dat.gam, method = "gam")

sort(coef(fit), decreasing = TRUE)[1:5]
sort(coef(fit))[1:5]

################################################################################

formula <- as.formula(~ re(sender))
data <- dat.gam

term_labels <- attr(stats::terms(formula), "term.labels")
parse_term <- function(lbl) {
  m <- regmatches(lbl, regexec("^(tv|nl|tvnl|re)\\((.+)\\)$", 
                               lbl))[[1]]
  if (length(m) == 3L) 
    list(type = m[2], var = trimws(m[3]))
  else list(type = "linear", var = lbl)
}
terms_info <- lapply(term_labels, parse_term)
ti <- terms_info[[1]]
v <- ti$var
ti$type == "re"
n <- nrow(data)

ev <- data[[paste0(v, "_ev")]]
all(dat.gam$sender_ev==ev)
nv <- data[[paste0(v, "_nv")]]
all(dat.gam$sender_nv==nv)

fmat <- factor(c(as.character(ev), as.character(nv)))
all(sp==fmat)

dim(fmat) <- c(n, 2L)
all(sp==fmat)

rc <- paste0(".RE_", v)
df <- list(one = rep(1, n), .I = cbind(case = rep(1, n), 
                                       ctrl = rep(-1, n)))
df[[rc]] <- fmat

bt <- function(x) paste0("`", x, "`")
rhs <- sprintf("s(%s, by = %s, bs = \"re\")", 
               bt(rc), bt(".I"))
fm <- stats::as.formula(paste("one ~ -1 +", paste(rhs, collapse = " + ")))
fit_try1 <- mgcv::gam(fm, family = stats::binomial(), data = df,
                 method = "REML")
all(coef(fit_try1)==coef(fit))

fit_try2 <- mgcv::gam(fm, family = stats::binomial(), data = df)
all(coef(fit_try2)==re.species)

################################################################################
