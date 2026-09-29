# Data

Income concept: **equivalised disposable (net) income** per person, modified OECD scale
(1.0 first adult, 0.5 each other person 14+, 0.3 each child under 14). Each household
member is assigned the household's equivalised income.

`survey_year` is the SILC wave; `income_year` is the reference year of the income (survey_year − 1).

- `policy_parameters.csv` — parameters of the child investment account (government announcement,
  `research/policy_measure.md`) and our own modelling assumptions (`source = assumption`: returns,
  inflation, income growth). Read by `R/child_account.R`.
- `elstat_silc_groups.csv`, `elstat_silc_indicators.csv` — ELSTAT, *Income Inequality — 2025 Survey
  on Income and Living Conditions* (press release 19 March 2026, `research/Income inequality ( 2025 ).pdf`),
  Tables 1–4: income shares and upper limits of quartiles and quintiles, Gini and S80/S20. Used only by
  `scripts/plot_income_distribution_household.R`, for the whole-population reference curve.

## `derived/`

Computed from the files above by `Rscript scripts/household_types.R` and
`Rscript scripts/child_account.R` (or `just derive`). They feed `doc/*.qmd` and `article/*.qmd`.
Do not edit them by hand.

| file | content |
|---|---|
| `household_types.csv` | per household type (couple <65 without children, couple with 1 child): real and model median/mean, Dagum parameters |
| `household_fit_check.csv` | per household type: fitted targets, observed vs fitted |
| `household_income_at_median.csv` | household net income of a family exactly at its type's real median |
| `household_medians_by_year.csv` | real median and mean per household type and year (ilc_di04) |
| `account_official_check.csv` | account function against the official example (24.652 / 49.304 / 64.109 / 77.062 €) |
| `account_calibration.csv` | deposit scenarios A/B/C: take-up, average first-year deposit, first-year cost, saving share s |
| `account_by_percentile.csv` | couple with 1 child <14 at P10–P90 and at the real median: deposits, value at 18 (nominal, real), state money |
| `account_by_quintile.csv` | by income quintile, per scenario: mean household income, share of children with an account, account at 18 of those taking part, expected account and state money at 18 per child, vs the universal amount |
| `account_inequality.csv` | concentration index, bottom/top 40% shares, Gini of state money at 18, share of children better off with a universal amount |
| `account_universal.csv` | budget-neutral fixed yearly amount per child, per scenario |
| `account_paths.csv` | account balance by year for P25/P50/P75 (scenario B) |
| `account_concentration.csv` | concentration curves of state money |

## `eurostat/`

Greece-only extracts from the Eurostat dissemination API, produced by
`Rscript scripts/fetch_eurostat.R` (see `eurostat/_index.csv` for fetch date and Eurostat update time).
Tidy long format: one row per cell, dimension codes plus `*_label` columns, `value`, `flag`.
`time` is the SILC survey year (income year = time − 1), except `hbs_*` (HBS year) and `tec00131` (national accounts year).

| file | content |
|---|---|
| `ilc_odbt11` | % of households putting money aside / drawing on savings / borrowing in a typical month, by income quintile (SILC 2020 ad-hoc module only) |
| `ilc_di01` | equivalised income cut-offs (deciles, quartiles, quintiles, P1–P5, P95–P99) and shares |
| `ilc_di03` | mean and median equivalised income by age group and sex (EUR, NAC, PPS) |
| `ilc_di04` | mean and median equivalised income by household type (e.g. `A2_2LT65`, `A2_DCH1`) |
| `ilc_li03` | % of a household type below 40–70% of the national median/mean |

Downloaded for context on saving capacity, not used by the scripts yet:

| file | content |
|---|---|
| `ilc_mdes04` | % unable to face an unexpected financial expense, by household type × above/below poverty line |
| `ilc_mdes09` | difficulty making ends meet (6 levels), by household type × poverty status |
| `ilc_mdsd02` | material and social deprivation rate by income quintile × household type |
| `ilc_lvho02` | tenure status (owner/tenant) by household type × poverty status |
| `ilc_lvho07b` | housing cost overburden rate by income quintile |
| `hbs_exp_t133` | HBS mean consumption expenditure by income quintile, PPS per household / per adult equivalent (latest 2020) |
| `tec00131` | gross household saving rate, national accounts |
