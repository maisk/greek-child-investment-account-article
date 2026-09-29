# Orchestration for the "Child investment account" article.
# Run `just` to list recipes. Everything runs from the project root.
#
# Pipeline:
#   fetch    Eurostat API           -> data/eurostat/*.csv                (network)
#   derive   data/                  -> data/derived/*.csv
#   plots    data/                  -> figures/*.png
#   docs     data/derived/, figures -> doc/*.md, doc/*.html            (quarto render)
#   articles data/derived/, figures -> article/*.html                  (quarto render)
#
# `year` is the SILC survey year; incomes refer to year - 1.

set shell := ["bash", "-euo", "pipefail", "-c"]

year := "2025"

# List available recipes
default:
    @just --list --unsorted

# Offline rebuild: derived CSVs, figures, docs and articles from the data already in data/
all: derive plots docs articles

# Full rebuild: download Eurostat tables first, then everything else
refresh: fetch all

# Download the Eurostat tables (Greece) into data/eurostat/
fetch:
    Rscript scripts/fetch_eurostat.R

# Compute the CSVs in data/derived/ that the docs and the article read
derive y=year:
    Rscript scripts/household_types.R {{y}}
    Rscript scripts/child_account.R {{y}}

# Household-type (couple <65 without children, couple with 1 child) densities, fit check and comparison
plot-household y=year:
    Rscript scripts/plot_income_distribution_household.R {{y}}

# Child account figures (value at 18, state money by quintile, concentration)
plot-account y=year:
    Rscript scripts/plot_child_account.R {{y}}

# All figures
plots y=year: (plot-household y) (plot-account y)

# Render every Quarto document in doc/ to Markdown and self-contained HTML
docs:
    for f in doc/*.qmd; do just doc "$(basename "$f" .qmd)"; done

# Render the HTML article in article/
articles:
    for f in article/*.qmd; do quarto render "$f" --quiet; echo "rendered ${f%.qmd}.html"; done

# Render one document, e.g. `just doc household_types`
doc name:
    quarto render doc/{{name}}.qmd --to gfm --quiet
    quarto render doc/{{name}}.qmd --to html -M embed-resources:true -M toc:true -M lang:el --quiet
    @echo "rendered doc/{{name}}.md and doc/{{name}}.html"

# Print the Dagum fits of the household types with fitted vs observed targets
fit y=year:
    Rscript -e 'source("R/income_distribution.R"); \
      for (h in household_types$hhcomp) { f <- fit_dagum(eurostat_hhcomp_targets(h, {{y}})); \
        cat("\n"); print(f); print(compare_fit(f), digits = 4) }'

# Show which generated files changed since the last commit
status:
    git status --short data/derived figures doc data/eurostat

# Remove Quarto render caches (generated outputs are kept)
clean:
    rm -rf doc/.quarto doc/*_files doc/*_cache article/.quarto article/*_files
