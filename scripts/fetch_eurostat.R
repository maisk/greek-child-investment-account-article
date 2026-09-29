# Download the Eurostat tables used in the analysis (Greece only) into
# data/eurostat/<dataset>.csv. Run from the project root:
#   Rscript scripts/fetch_eurostat.R

source("R/eurostat.R")

datasets <- c(
  ilc_odbt11   = "Savings in a typical month by household habits and income quintile (SILC 2020 ad-hoc module)",
  ilc_di01     = "Distribution of income by quantiles (cut-off points and shares)",
  ilc_di03     = "Mean and median equivalised income by age and sex",
  ilc_di04     = "Mean and median equivalised income by household composition",
  ilc_li03     = "Share of people below 40-70% of national mean/median (poverty thresholds), by household type",
  # Context on saving capacity; downloaded but not used by the scripts yet.
  ilc_mdes04   = "Inability to face unexpected financial expenses, by household type and poverty status",
  ilc_mdes09   = "Inability to make ends meet, by household type and poverty status",
  ilc_mdsd02   = "Material and social deprivation rate by income quintile and household type",
  ilc_lvho02   = "Distribution of population by tenure status, household type and poverty status",
  ilc_lvho07b  = "Housing cost overburden rate by income quintile",
  hbs_exp_t133 = "HBS mean consumption expenditure by income quintile (PPS)",
  tec00131     = "Gross household saving rate (national accounts)"
)

out_dir <- "data/eurostat"
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

index <- data.frame(dataset = names(datasets), description = unname(datasets),
                    eurostat_label = NA_character_, updated = NA_character_, rows = NA_integer_)
for (i in seq_along(datasets)) {
  ds <- names(datasets)[i]
  message("fetching ", ds)
  df <- fetch_eurostat(ds, list(geo = "EL"))
  write.csv(df, file.path(out_dir, paste0(ds, ".csv")), row.names = FALSE, na = "")
  index$eurostat_label[i] <- attr(df, "label")
  index$updated[i]        <- attr(df, "updated")
  index$rows[i]           <- nrow(df)
}
write.csv(index, file.path(out_dir, "_index.csv"), row.names = FALSE)
print(index[, c("dataset", "rows", "updated")])
