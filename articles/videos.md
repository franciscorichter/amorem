# Videos

Two series of short videos about amorem. Every number on screen is
computed by running the package; the narration is in English.

## Night Sky Atlas

One real dataset per card, seen as a night sky: actors are stars, each
event is a streak of light between two of them, and time runs along the
horizon. Each card ends on one finding computed with amorem. The cards
stand alone and can be watched in any order.

No. 1

Over Washington

Every leader-to-leader visit of the United States, 1945–2019. A country
whose leader has just visited Washington is about twice as likely to be
the president's next stop (2.08 times the rate, 95% interval 1.60 to
2.69).

Try it in R:
[`amorem::us_leader_visits`](https://franciscorichter.github.io/amorem/reference/us_leader_visits.md)

## Time, Rate, History

Eleven short lectures that build relational event models from the ground
up: events, rates, history as a covariate, the partial likelihood,
case-control sampling, smooth effects, goodness of fit and global
covariates. They are meant to be watched in order. They also play on the
Luche channel on YouTube.

# An error occurred.

Unable to execute JavaScript.

Episode 1

The data are events, not a network

A relational event model starts from a log: who acted towards whom, and
when.

# An error occurred.

Unable to execute JavaScript.

Episode 2

Every pair has a clock

Give every ordered pair its own exponential clock.

# An error occurred.

Unable to execute JavaScript.

Episode 3

Coefficients multiply rates

Each pair's rate is a baseline times exp(beta times x).

# An error occurred.

Unable to execute JavaScript.

Episode 4

History becomes a covariate

Endogenous statistics turn a log's own past into covariates:
reciprocity, transitivity, recency and their variants.

# An error occurred.

Unable to execute JavaScript.

Episode 5

Which dyad fired?

Given that an event happened, which pair was it? The partial likelihood
asks only that question.

# An error occurred.

Unable to execute JavaScript.

Episode 6

Compare with a few who did not

The partial likelihood sums over every pair at risk.

# An error occurred.

Unable to execute JavaScript.

Episode 7

How many controls?

How many non-events should be sampled per event? On a fixed history,
more controls narrow the spread of the estimate without moving its
centre: from one control to ten, the spread falls about three times.

# An error occurred.

Unable to execute JavaScript.

Episode 8

Ghosts read the past but never write it

A sampled non-event did not happen, so it must read the history to get
its covariates but must never write into it.

# An error occurred.

Unable to execute JavaScript.

Episode 9

With one control, a regression on differences

With one control per event, the conditional logit becomes a logistic
regression without intercept on case-minus-control differences.

# An error occurred.

Unable to execute JavaScript.

Episode 10

Is the model wrong?

Rank the candidate models by AIC on one shared case-control sample, then
check the winner.

# An error occurred.

Unable to execute JavaScript.

Episode 11

Why the weekday cancels

A covariate shared by every pair at the same moment, such as the weekday
or El Nino, takes the same value for an event and its controls, so it
cancels like the baseline.
