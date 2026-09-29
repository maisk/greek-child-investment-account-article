# The Child Investment Account and Inequality in Greece

*Who gets the state's matching money in Greece's "Investment Account for the New Generation", and what a
flat grant with the same budget would do instead.*

An article in Greek, **«Ο λογαριασμός για τη νέα γενιά: ποιο παιδί παίρνει τα κρατικά χρήματα;»**,
published at <https://maistrelis.com/articles/greek-child-investment-account/>. It is written in Quarto
(`article/02_child_account.qmd`) and built from official statistics (Eurostat, EU-SILC) and the government's
announcement (September 2026) with a reproducible R pipeline.

The measure: parents deposit into an investment account for their child and the state matches every euro
1:1, up to 1,200 € a year, for 18 years, with no income test. The article asks which families will be
able to deposit, and therefore which children the state money reaches. It covers:

- the account rule, checked against the government's official example;
- a couple with one child across the income distribution, under three deposit scenarios calibrated to
  the government's take-up and first-year cost;
- where the state money goes by income quintile, and the starting capital of children at 18;
- a budget-neutral alternative: the same amount for every child;
- the sensitivity of the results to the assumptions.

Companion project: [`greek-household-incomes`](https://github.com/maisk/greek-household-incomes), an article on Greek household
incomes and inequality that explains the basic concepts (equivalised income, quintiles, Gini). The link to
it is the `incomes_article` parameter at the top of `article/02_child_account.qmd`.

## Layout

| folder | content | source or generated |
|---|---|---|
| `R/` | account rule and inequality measures; shared Dagum, Eurostat and chart functions | source |
| `scripts/` | one script per step: fetch, derive CSVs, draw figures | source |
| `data/` | policy parameters and our assumptions, ELSTAT tables | source |
| `data/eurostat/` | Eurostat extracts | downloaded (`just fetch`) |
| `data/derived/` | every number used in the texts | generated (`just derive`) |
| `figures/` | charts | generated (`just plots`) |
| `doc/*.qmd` | technical note on the household-type income distributions | source |
| `doc/*.md` | rendered note, readable on GitHub | generated (`just docs`) |
| `article/*.qmd` | the article | source |
| `research/` | the government announcement and the ELSTAT press release (PDFs kept locally, not committed) | reference material |

`data/README.md` describes every data file and derived CSV.

## Rebuild

```sh
just all       # derived CSVs, figures, docs and the article, from the data already in data/
just refresh   # download the Eurostat tables first, then everything else
just           # list all recipes
```

The rendered article (`article/*.html`) and the HTML note (`doc/*.html`) are not committed; `just all`
recreates them.

Requirements: R (≥ 4.3) with `ggplot2`, `knitr`, `rmarkdown` and `jsonlite`; [Quarto](https://quarto.org);
[just](https://github.com/casey/just).

## Reproducibility rule

No number in the article or the note is typed by hand. Every figure is read from a CSV in
`data/derived/` or from `data/policy_parameters.csv`. To change a number, change the script or the
parameter that produces it and rerun `just all`.

## Shared code

`R/income_distribution.R`, `R/plot_helpers.R`, `R/eurostat.R`, `scripts/household_types.R`,
`scripts/plot_income_distribution_household.R`, `doc/household_types.qmd` and the two ELSTAT tables in
`data/` are also used by the companion project. They are kept as identical copies in both repositories;
change them in both.

## License

The repository holds three kinds of material under three sets of terms:

| what | licence |
|---|---|
| the code: `R/`, `scripts/`, `justfile` | [MIT](LICENSE) |
| the text and the figures: `article/`, `doc/`, `figures/`, the READMEs | [CC BY 4.0](LICENSE-CC-BY-4.0) |
| the data: `data/` | the terms of each source (Eurostat, ELSTAT), see [`data/README.md`](data/README.md#licences-of-the-sources) |

Code and text have different licences because Creative Commons
[recommends against](https://creativecommons.org/faq/#can-i-apply-a-creative-commons-license-to-software)
its licences for software. MIT asks for the same thing as CC BY: keep the author's name.

To credit the article: Kostas Maistrelis, «Ο λογαριασμός για τη νέα γενιά: ποιο παιδί παίρνει τα κρατικά
χρήματα;», 2026, <https://maistrelis.com/articles/greek-child-investment-account/>, CC BY 4.0.
