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

No. 2

Over a Classroom

One 44-minute US high-school class period, 16 October 1996: 20 people
and 511 turns of talk. A turn back to someone who spoke to you in the
last minute comes at 9.69 times the rate of an otherwise similar pair
where that did not happen (95% interval 7.95 to 11.83).

Try it in R:
[`amorem::classroom_events`](https://franciscorichter.github.io/amorem/reference/classroom_events.md)

No. 3

Over the football world

Men's international football, 1872 to 2026: 49,945 matches between 337
teams. A pair that met a year ago plays again at 2.3 times the rate of a
pair that last met ten years ago (95% interval 2.2 to 2.5).

Try it in R:
[`amorem::football_results`](https://franciscorichter.github.io/amorem/reference/football_results.md)

No. 4

Over Europe

18,703 flights the OpenSky Network recorded between 60 European airports
in April 2020. A route flown the other way in the last 12 hours carries
the next flight at 3.83 times the rate of one flown the other way only
earlier (95% interval 3.64 to 4.03).

Data: OpenSky Network, CC BY 4.0

No. 5

Over the Office

The first 60 days of e-mail in a manufacturing company in Poland, 2010:
14,962 e-mails among 167 employees. Copies flow to someone who has
already written to the sender at 7.04 times the rate of a pair where
they have not (95% interval 5.61 to 8.82).

Try it in R:
[`amorem::radoslaw_email`](https://franciscorichter.github.io/amorem/reference/radoslaw_email.md)

No. 7

Over Copenhagen

28 days of calls and texts among 608 students of the Technical
University of Denmark. 20.9% of all calls (754 of 3,600) go back to
someone who called the caller in the hour before.

Try it in R:
[`amorem::copenhagen_calls`](https://franciscorichter.github.io/amorem/reference/copenhagen.md)

No. 8

Over the Earth

11,730 first records of alien species in 259 regions of the world, 1880
to 2005. A species already in 4 regions reaches its next region at 1.97
times the rate of a species in 1 (95% interval 1.76 to 2.20).

Try it in R:
[`amorem::alien_invasions`](https://franciscorichter.github.io/amorem/reference/alien_invasions.md)

No. 9

Over Capitol Hill

Every bill of the 118th US Congress, 2023 to 2025: 16,213 bills and
162,424 cosponsor signatures. 21.7% of the signatures cross party lines
(35,300 of 162,424): 20.4% in the House, 28.2% in the Senate.

Try it in R:
[`amorem::congress_bills_118`](https://franciscorichter.github.io/amorem/reference/congress_bills_118.md)

No. 10

Over London

19,120 bike journeys between London's 60 busiest docking stations,
February 2026. Riding back along a journey made in the last 12 hours
comes at 2.42 times the rate of riding back along one made only earlier
(95% interval 2.31 to 2.54).

Data: TfL cycle hire journeys, February 2026. Powered by TfL Open Data.

No. 11

Over Lichess

7,025 rated games between the 60 most active Lichess players, January
2013. A pair that met in the last hour is more than ten times as likely
to play next as one that met only earlier (seed 1: 17, 95% interval 12
to 24; five random draws: 14 to 21).

Data: Lichess open database, CC0

No. 12

Over Africa

2,959 foreign-minister visits between 170 countries, reported by 30
African ministries, 2010 to 2022. A minister whose counterpart came in
the past year visits back next at 1.38 times the rate (95% interval 1.19
to 1.59).

Data: Burman Roy et al., CC BY 4.0

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
