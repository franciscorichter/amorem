# Data catalogue

This catalogue documents the relational event data and global covariates
collected for amorem: what each dataset is, where it comes from, what
its licence allows, and a profile of its structure. It covers 78
datasets.

## What the licences allow

Each licence was read on the publisher’s own page (Harvard Dataverse,
Zenodo and Figshare records, the providers’ terms pages, or the licence
file shipped with the data) on 2026-10-17. amorem is released under the
MIT licence, so a dataset can be bundled with it only when its terms
allow redistribution without conditions that the MIT licence cannot
carry.

| verdict | datasets |
|:---|---:|
| public domain, CC0, CC BY, MIT, Open Government Licence or explicitly unrestricted: may be bundled with attribution | 32 |
| no licence stated (only a request to cite): not redistributed | 25 |
| non-commercial licence (SocioPatterns, CC BY-NC-SA): not redistributed | 13 |
| GPL-3: compatible only with a GPL-licensed package | 4 |
| share-alike (CC BY-SA): compatible only with a package under the same terms | 3 |
| licence differs between datasets of the collection | 1 |

10 of the datasets that may be bundled ship with amorem (see [Bundled
datasets](https://franciscorichter.github.io/amorem/articles/datasets.md)).
Three datasets bundled in earlier releases (CollegeMsg, Email-EU-core
and the Social Evolution study) come from sources without a licence or
under GPL-3; their status is under review. Datasets that cannot be
redistributed are documented here with code that downloads them from
their source; the figures and numbers on the topic pages are aggregates,
not the data.

## Topic pages

- [Face-to-Face and Proximity
  Contacts](https://franciscorichter.github.io/amorem/articles/data-contact.md):
  14 datasets
- [Email, Messages, Calls and
  Radio](https://franciscorichter.github.io/amorem/articles/data-communication.md):
  10 datasets
- [Online
  Platforms](https://franciscorichter.github.io/amorem/articles/data-online.md):
  10 datasets
- [Citations](https://franciscorichter.github.io/amorem/articles/data-citations.md):
  4 datasets
- [International Relations and
  Conflict](https://franciscorichter.github.io/amorem/articles/data-political.md):
  11 datasets
- [Mobility, Ecology and
  Epidemics](https://franciscorichter.github.io/amorem/articles/data-mobility-ecology.md):
  5 datasets
- [Games and
  Sports](https://franciscorichter.github.io/amorem/articles/data-sports.md):
  4 datasets
- [Hyperevents](https://franciscorichter.github.io/amorem/articles/data-hyperevents.md):
  6 datasets
- [Global
  Covariates](https://franciscorichter.github.io/amorem/articles/data-covariates.md):
  9 datasets

## All datasets

| dataset | kind | licence | amorem | profile |
|:---|:---|:---|:---|:---|
| [4PCAN alter nominations](https://franciscorichter.github.io/amorem/articles/data-communication.md) | events | CC BY 4.0 | can bundle | yes |
| [Africa’s diplomatic visits (foreign ministers) 2010-2022](https://franciscorichter.github.io/amorem/articles/data-political.md) | events | CC BY 4.0 | can bundle | yes |
| [Alien Species First Records Database v4.0 (Seebens et al.)](https://franciscorichter.github.io/amorem/articles/data-mobility-ecology.md) | events | CC BY 4.0 | can bundle | yes |
| [Alien species first records prepared for REMs (Juozaitienė et al.)](https://franciscorichter.github.io/amorem/articles/data-mobility-ecology.md) | events | CC0 1.0 | bundled as `alien_invasions` | yes |
| [Copenhagen Networks Study interaction data](https://franciscorichter.github.io/amorem/articles/data-communication.md) | events | MIT | bundled as `copenhagen_calls`, `copenhagen_sms`, `copenhagen_actors` | yes |
| [COVID-19 transmission chains, Bucharest](https://franciscorichter.github.io/amorem/articles/data-mobility-ecology.md) | events | CC BY 4.0 | can bundle | yes |
| [Diplomatic visits of the foreign ministers of Russia and Ukraine 2021-2024](https://franciscorichter.github.io/amorem/articles/data-political.md) | events | CC0 1.0 | can bundle | yes |
| [EIA daily Brent and WTI spot prices](https://franciscorichter.github.io/amorem/articles/data-covariates.md) | covariate | public domain (US Government work) | can bundle | yes |
| [GDELT event database (1979 file and one daily file)](https://franciscorichter.github.io/amorem/articles/data-political.md) | events | unrestricted use and redistribution with citation | can bundle | yes |
| [IMGW daily synoptic weather, Poland 2010](https://franciscorichter.github.io/amorem/articles/data-covariates.md) | covariate | Polish public-sector open data re-use | can bundle | yes |
| [International football results 1872-present](https://franciscorichter.github.io/amorem/articles/data-sports.md) | events | CC0 1.0 | bundled as `football_results` | yes |
| [Italy’s diplomatic visits 2000-2023](https://franciscorichter.github.io/amorem/articles/data-political.md) | events | CC BY 4.0 | can bundle | yes |
| [Lichess rated standard games, January 2013](https://franciscorichter.github.io/amorem/articles/data-sports.md) | events | CC0 | can bundle | yes |
| [Manufacturing company email metadata and corporate hierarchy](https://franciscorichter.github.io/amorem/articles/data-communication.md) | events | CC0 1.0 | bundled as `radoslaw_email`, `radoslaw_hierarchy` | yes |
| [NOAA CPC ENSO indices (ONI, SST indices)](https://franciscorichter.github.io/amorem/articles/data-covariates.md) | covariate | public domain (US Government work) | bundled as `oni` | yes |
| [NOAA GHCN-Daily weather for the bundled logs’ periods](https://franciscorichter.github.io/amorem/articles/data-covariates.md) | covariate | public domain (US Government work) | bundled as `daily_weather` | yes |
| [Open-Meteo historical weather, London 2026 and Warsaw 2010](https://franciscorichter.github.io/amorem/articles/data-covariates.md) | covariate | CC BY 4.0 | can bundle | yes |
| [OpenAlex: works of the journal Social Networks](https://franciscorichter.github.io/amorem/articles/data-hyperevents.md) | hyperevents | CC0 1.0 | can bundle | yes |
| [OpenSky COVID-19 flight list, April 2020](https://franciscorichter.github.io/amorem/articles/data-mobility-ecology.md) | events | CC BY 4.0 | can bundle | yes |
| [POLECAT weekly event data 2024](https://franciscorichter.github.io/amorem/articles/data-political.md) | events | CC0 1.0 | can bundle | yes |
| Polish statutory holidays (Dziennik Ustaw) | covariate | public domain (Polish normative acts, Art. 4 copyright act) | can bundle | no: legal texts (holiday statutes) |
| [Public holidays (Nager.Date API): PL 2010, US 2004/2008/2009, GB 2026](https://franciscorichter.github.io/amorem/articles/data-covariates.md) | covariate | facts (holiday dates); API terms not recorded | bundled as `public_holidays` | yes |
| [Retrosheet MLB game logs 1871-2024](https://franciscorichter.github.io/amorem/articles/data-sports.md) | events | free use with required notice | can bundle | yes |
| [TfL Santander Cycles journeys, February 2026](https://franciscorichter.github.io/amorem/articles/data-mobility-ecology.md) | events | Open Government Licence v2.0 (TfL) | can bundle | yes |
| UC Irvine academic calendars 2003-2005 | covariate | facts (dates); pages (c) UC Regents | can bundle | no: calendar web pages |
| [UCDP conflict data (GED, dyadic, actor, interstate onsets)](https://franciscorichter.github.io/amorem/articles/data-political.md) | events | CC BY 4.0 | bundled as `ucdp_dyads` | yes |
| [UN General Assembly ideal points](https://franciscorichter.github.io/amorem/articles/data-covariates.md) | covariate | CC0 1.0 | can bundle | yes |
| [UN General Assembly roll-call votes 1946-2013](https://franciscorichter.github.io/amorem/articles/data-covariates.md) | events | CC0 1.0 | can bundle | yes |
| [UNHCR refugee population statistics (refugees R package)](https://franciscorichter.github.io/amorem/articles/data-political.md) | events | CC BY 4.0 | can bundle | yes |
| [US Congress bill status, 118th Congress (sponsors, cosponsors)](https://franciscorichter.github.io/amorem/articles/data-hyperevents.md) | hyperevents | public domain (17 U.S.C. 105) | bundled as `congress_bills_118`, `congress_members_118` | yes |
| [US leader-to-leader diplomatic visits 1946-2019](https://franciscorichter.github.io/amorem/articles/data-political.md) | events | CC0 1.0 | bundled as `us_leader_visits` | yes |
| [World Bank commodity prices (Pink Sheet)](https://franciscorichter.github.io/amorem/articles/data-covariates.md) | covariate | CC BY 4.0 | can bundle | yes |
| [eventnet example data (Enron, Apache, Wikipedia hyperevents)](https://franciscorichter.github.io/amorem/articles/data-communication.md) | hyperevents | GPL-3.0 (source repository/package) | GPL only | yes |
| [goldfish package data: fisheries treaties, RFID validity, Social Evolution](https://franciscorichter.github.io/amorem/articles/data-political.md) | events | GPL-3.0 (source repository/package) | bundled as `social_evolution_calls`, `social_evolution_friendship`, `social_evolution_actors` since an earlier release; licence under review | yes |
| [networkDynamicData package data](https://franciscorichter.github.io/amorem/articles/data-communication.md) | events | GPL-3.0 (source repository/package) | GPL only | yes |
| [statnet relevent workshop data (WTC radio, classroom)](https://franciscorichter.github.io/amorem/articles/data-communication.md) | events | GPL-3.0 (source repository/package) | GPL only | yes |
| [ATOP alliance treaty obligations 5.1](https://franciscorichter.github.io/amorem/articles/data-political.md) | events | none stated | obtain from source | yes |
| [Benson higher-order data: email-Enron, email-Eu, congress-bills](https://franciscorichter.github.io/amorem/articles/data-hyperevents.md) | hyperevents | none stated | obtain from source | yes |
| [Benson ScHoLP timestamped simplices](https://franciscorichter.github.io/amorem/articles/data-hyperevents.md) | hyperevents | none stated | obtain from source | yes |
| [Cline Center Phoenix NYT event data 1945-2005](https://franciscorichter.github.io/amorem/articles/data-political.md) | events | unknown (databank page returned 403) | obtain from source | yes |
| [Enron email with recipient lists (Perry & Wolfe)](https://franciscorichter.github.io/amorem/articles/data-hyperevents.md) | hyperevents | none stated | obtain from source | yes |
| [GH Archive: one hour of public GitHub events](https://franciscorichter.github.io/amorem/articles/data-online.md) | events | none stated | obtain from source | yes |
| [Honeybee trophallaxis interactions (Gernat et al. 2018)](https://franciscorichter.github.io/amorem/articles/data-contact.md) | events | none stated for data (software AGPL-3) | obtain from source | yes |
| [KDD Cup 2003 arXiv hep-th papers, citations, dates](https://franciscorichter.github.io/amorem/articles/data-citations.md) | hyperevents | none stated | obtain from source | yes |
| [KONECT: chess games](https://franciscorichter.github.io/amorem/articles/data-sports.md) | events | unknown (site unreachable 2026-10-17) | obtain from source | yes |
| [KONECT: Dutch college friendship waves (van de Bunt)](https://franciscorichter.github.io/amorem/articles/data-communication.md) | events | unknown (site unreachable 2026-10-17) | obtain from source | yes |
| [KONECT: Haggle device contacts](https://franciscorichter.github.io/amorem/articles/data-contact.md) | events | unknown (site unreachable 2026-10-17) | obtain from source | yes |
| [NBER US patent citations 1975-1999](https://franciscorichter.github.io/amorem/articles/data-citations.md) | events | none stated (freely available; cite Hall, Jaffe & Trajtenberg 2001) | obtain from source | yes |
| [SNAP: arXiv hep-ph citations with dates](https://franciscorichter.github.io/amorem/articles/data-citations.md) | events | none stated | obtain from source | yes |
| [SNAP: arXiv hep-th citations with dates](https://franciscorichter.github.io/amorem/articles/data-citations.md) | events | none stated | obtain from source | yes |
| [SNAP: Ask Ubuntu interactions](https://franciscorichter.github.io/amorem/articles/data-online.md) | events | none stated | obtain from source | yes |
| [SNAP: Bitcoin Alpha trust ratings](https://franciscorichter.github.io/amorem/articles/data-online.md) | events | none stated | obtain from source | yes |
| [SNAP: Bitcoin OTC trust ratings](https://franciscorichter.github.io/amorem/articles/data-online.md) | events | none stated | obtain from source | yes |
| [SNAP: CollegeMsg (UC Irvine messages)](https://franciscorichter.github.io/amorem/articles/data-communication.md) | events | none stated | bundled as `college_msg` since an earlier release; licence under review | yes |
| [SNAP: email-Eu-core temporal (four departments)](https://franciscorichter.github.io/amorem/articles/data-communication.md) | events | none stated | bundled as `email_eu_core` since an earlier release; licence under review | yes |
| SNAP: face-to-face interactions in Resistance games | events | none stated | obtain from source | no: many small game networks rather than one log |
| [SNAP: MathOverflow interactions](https://franciscorichter.github.io/amorem/articles/data-online.md) | events | none stated | obtain from source | yes |
| [SNAP: MOOC user actions](https://franciscorichter.github.io/amorem/articles/data-online.md) | events | none stated | obtain from source | yes |
| [SNAP: Super User interactions](https://franciscorichter.github.io/amorem/articles/data-online.md) | events | none stated | obtain from source | yes |
| [SNAP: Wikipedia requests for adminship votes](https://franciscorichter.github.io/amorem/articles/data-online.md) | events | none stated | obtain from source | yes |
| [SNAP: Wikipedia talk-page messages](https://franciscorichter.github.io/amorem/articles/data-online.md) | events | none stated | obtain from source | yes |
| [SocioPatterns: ACM Hypertext 2009 conference contacts](https://franciscorichter.github.io/amorem/articles/data-contact.md) | events | CC BY-NC-SA | obtain from source | yes |
| [SocioPatterns: baboon proximity and observations (Rousset)](https://franciscorichter.github.io/amorem/articles/data-contact.md) | events | CC BY-NC-SA | obtain from source | yes |
| SocioPatterns: co-location data, several settings | events | CC BY-NC-SA | obtain from source | no: repackages the SocioPatterns sets above |
| [SocioPatterns: high school contacts 2011 and 2012 (Marseille)](https://franciscorichter.github.io/amorem/articles/data-contact.md) | events | CC BY-NC-SA | obtain from source | yes |
| [SocioPatterns: high school contacts, diaries, friendship, Facebook 2013](https://franciscorichter.github.io/amorem/articles/data-contact.md) | events | CC BY-NC-SA | obtain from source | yes |
| [SocioPatterns: hospital ward contacts (Lyon)](https://franciscorichter.github.io/amorem/articles/data-contact.md) | events | CC BY-NC-SA | obtain from source | yes |
| [SocioPatterns: household contacts in rural Kenya](https://franciscorichter.github.io/amorem/articles/data-contact.md) | events | CC BY-NC-SA | obtain from source | yes |
| [SocioPatterns: Infectious exhibition contacts (Dublin)](https://franciscorichter.github.io/amorem/articles/data-contact.md) | events | CC BY-NC-SA | obtain from source | yes |
| [SocioPatterns: primary school contacts (Lyon)](https://franciscorichter.github.io/amorem/articles/data-contact.md) | events | CC BY-NC-SA | obtain from source | yes |
| [SocioPatterns: SFHH conference contacts (Nice)](https://franciscorichter.github.io/amorem/articles/data-contact.md) | events | CC BY-NC-SA | obtain from source | yes |
| [SocioPatterns: village contacts in rural Malawi](https://franciscorichter.github.io/amorem/articles/data-contact.md) | events | CC BY-NC-SA | obtain from source | yes |
| [SocioPatterns: workplace contacts 2013 (InVS)](https://franciscorichter.github.io/amorem/articles/data-contact.md) | events | CC BY-NC-SA | obtain from source | yes |
| [SocioPatterns: workplace contacts 2015 (InVS)](https://franciscorichter.github.io/amorem/articles/data-contact.md) | events | CC BY-NC-SA | obtain from source | yes |
| [XGI-DATA: email-enron, senate-bills, sfhh-conference hypergraphs](https://franciscorichter.github.io/amorem/articles/data-hyperevents.md) | hyperevents | CC BY 4.0 per Zenodo record (sfhh-conference derives from SocioPatterns CC BY-NC-SA) | per dataset | yes |
| [Network Repository: Enron employees email](https://franciscorichter.github.io/amorem/articles/data-communication.md) | events | CC BY-SA | share-alike | yes |
| [Network Repository: Facebook-like forum](https://franciscorichter.github.io/amorem/articles/data-online.md) | events | CC BY-SA | share-alike | yes |
| Stack Exchange data dump: Operations Research site | hyperevents | CC BY-SA 4.0 | share-alike | no: 7z archive, not read here |

## How the profiles are built

Every dataset is read from its files as downloaded by a reader in
[`data-raw/catalogue/readers.R`](https://github.com/franciscorichter/amorem/blob/main/data-raw/catalogue/readers.R)
into a table of `(sender, receiver, time)` events, of hyperevents with
sender and receiver sets, or of a time series.
[`profile.R`](https://github.com/franciscorichter/amorem/blob/main/data-raw/catalogue/profile.R)
then computes the same statistics for every dataset:

- **repetition**: the share of events whose pair occurred before, next
  to the share expected if every event picked a pair uniformly at random
  among all pairs of the actors present;
- **reciprocity** (directed data): the share of events answering an
  earlier event in the opposite direction;
- **burstiness**: $`B = (\sigma - \mu)/(\sigma + \mu)`$ of the gaps
  between successive events of the same pair, 0 for a Poisson process
  and close to 1 when events of a pair come in bursts;
- **concentration**: the Gini coefficient of actor activity and the
  share of events involving the most active tenth of the actors;
- **daily cycle**, when the time stamps carry clock time;
- for directed logs, a conditional logit on the first 4,000 events with
  one control per event and three log-count statistics (sender activity,
  receiver popularity, past reciprocating events), using the
  case-control history of
  [`endogenous_features()`](https://franciscorichter.github.io/amorem/reference/endogenous_features.md).

Licences, sources and checksums are recorded in
[`licences.csv`](https://github.com/franciscorichter/amorem/blob/main/data-raw/catalogue/licences.csv)
and in the `SOURCES` and `SHA256SUMS` files of each download.
