# Simulates the child investment account for couples with one child under 14
# (Eurostat household type A2_DCH1) across the income distribution, under three
# parental-behaviour scenarios, and compares the state money with a
# budget-neutral fixed amount paid to every child. Writes CSVs to data/derived/
# for article/02_child_account.qmd.
#   Rscript scripts/child_account.R [survey_year]
#
# Scenarios (who deposits, and how much, per year):
#   A  income-independent: a random third of families deposits the government's
#      implied average (first-year cost / infants) scaled with the cap.
#   B  saving propensity: the chance to deposit follows the share of households
#      putting money aside in the family's national income quintile (ilc_odbt11),
#      rescaled so that one third deposits; depositors put in a share s of income
#      above the poverty line, up to the cap. s is set so that the average first-year
#      deposit equals the government's implied average.
#   C  upper bound: every family above the poverty line deposits like in B.
# Universal alternative: every child receives each year the average state money
# per child (all children, depositors or not) of the scenario, with no parental money.
#
# Outputs (data/derived/):
#   account_official_check.csv  our account function against the official example
#   account_calibration.csv     scenario parameters and fiscal checks
#   account_by_percentile.csv   families at P10..P90 (and at the real median), per scenario and return
#   account_by_quintile.csv     by income quintile of the household type: share of children with an
#                               account, account at 18 of those taking part, account and state money
#                               per child
#   account_inequality.csv      concentration index, shares, Gini of state money at 18
#   account_universal.csv       yearly fixed amount of the universal alternative
#   account_paths.csv           account balance by year for P25/P50/P75 (scenario B)
#   account_concentration.csv   concentration curves of state money

source("R/income_distribution.R")
source("R/child_account.R")

args <- commandArgs(trailingOnly = TRUE)
year <- if (length(args)) as.integer(args[1]) else 2025L
out_dir <- "data/derived"
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

p      <- read_policy()
years  <- p$years
tt     <- seq_len(years)
caps   <- match_cap(tt, p)
returns <- c(main = p$return_main, alt = p$return_alt)
scale  <- oecd_scale(adults = 2, children_under14 = 1)
income_year <- year - 1

# ---- Inputs ------------------------------------------------------------------------

fit <- fit_dagum(eurostat_hhcomp_targets("A2_DCH1", year))
fa <- fit$par[["a"]]; fp <- fit$par[["p"]]; fb <- fit$par[["b"]]

di03 <- read.csv("data/eurostat/ilc_di03.csv")
di03 <- di03[di03$time == year & di03$sex == "T" & di03$unit == "EUR", ]
nat_median <- di03$value[di03$age == "TOTAL" & di03$statinfo == "MED_EI"]
lt6_median <- di03$value[di03$age == "Y_LT6" & di03$statinfo == "MED_EI"]
type_median <- fit$targets$quantiles$x[fit$targets$quantiles$src == "ilc_di04 median"]
floor_eq <- p$poverty_line_share * nat_median

di01 <- read.csv("data/eurostat/ilc_di01.csv")
qcut <- di01$value[di01$time == year & di01$unit == "EUR" & di01$statinfo == "TC" &
                   di01$quant_inc %in% paste0("QU", 1:4)]
qcut <- sort(qcut)

sv <- read.csv("data/eurostat/ilc_odbt11.csv")
sv <- sv[sv$hhtype == "ASD_M" & grepl("^QU", sv$quant_inc), ]
save_share <- sv$value[order(sv$quant_inc)] / 100   # QU1..QU5
save_year  <- unique(sv$time)

# Household income in deposit year t of a family with equivalised income eq in the
# income year: incomes and the poverty line grow at the nominal rate.
growth <- function(t) (1 + p$income_growth)^(p$first_deposit_year + t - 1 - income_year)
hh_income <- function(eq, t) eq * scale * growth(t)
floor_t   <- function(t) floor_eq * scale * growth(t)
nat_quintile <- function(eq) findInterval(eq, qcut) + 1

target_avg <- p$gov_first_year_cost / p$gov_first_year_infants

# ---- Calibration ------------------------------------------------------------------

n <- 2000
u <- (seq_len(n) - 0.5) / n
eq_grid <- qdagum(u, fa, fp, fb)

deposits_rule <- function(eq, s) {
  sapply(tt, function(t) parent_deposit(hh_income(eq, t), floor_t(t), s, caps[t]))
}

above <- eq_grid > floor_eq
k <- p$gov_takeup / mean(save_share[nat_quintile(eq_grid)] * above)
if (k * max(save_share) > 1) stop("participation probability above 1; the rescaling needs clipping")
prob_B <- k * save_share[nat_quintile(eq_grid)] * above

avg_first <- function(s, prob) {
  sum(prob * parent_deposit(hh_income(eq_grid, 1), floor_t(1), s, caps[1])) / sum(prob)
}
s <- uniroot(function(s) avg_first(s, prob_B) - target_avg, c(1e-5, 1), tol = 1e-12)$root

scenarios <- list(
  A = list(label = "Α: συμμετοχή ανεξάρτητη από το εισόδημα",
           prob = function(eq) rep(p$gov_takeup, length(eq)),
           dep  = function(eq) matrix(rep(target_avg / caps[1] * caps, each = length(eq)), length(eq))),
  B = list(label = "Β: συμμετοχή κατά τη ροπή αποταμίευσης",
           prob = function(eq) k * save_share[nat_quintile(eq)] * (eq > floor_eq),
           dep  = function(eq) deposits_rule(eq, s)),
  C = list(label = "Γ: καταθέτουν όλοι όσοι μπορούν",
           prob = function(eq) as.numeric(eq > floor_eq),
           dep  = function(eq) deposits_rule(eq, s))
)

# ---- Official example check ---------------------------------------------------------

official <- data.frame(
  item = c("state_total", "total_deposits", "value_r3", "value_r5"),
  official = c(p$official_state_total, p$official_total_deposits, p$official_value_r3, p$official_value_r5),
  model = c(sum(caps), 2 * sum(caps), account_value(2 * caps, 0.03), account_value(2 * caps, 0.05)))
official$diff <- official$model - official$official
official$rel_diff_pct <- 100 * official$diff / official$official
write.csv(official, file.path(out_dir, "account_official_check.csv"), row.names = FALSE)

# ---- Grid results per scenario --------------------------------------------------------

grid_results <- lapply(names(scenarios), function(sc) {
  S <- scenarios[[sc]]
  prob <- S$prob(eq_grid)
  dep  <- S$dep(eq_grid)                       # n x years, deposit if the family takes part
  list(prob = prob, dep = dep,
       state_fv = sapply(returns, function(r) as.vector(dep %*% fv_factors(years, r))),
       universal = colSums(prob * dep) / n)      # yearly average state money per child
})
names(grid_results) <- names(scenarios)

calib <- do.call(rbind, lapply(names(scenarios), function(sc) {
  g <- grid_results[[sc]]
  takeup <- mean(g$prob * (g$dep[, 1] > 0))
  avg1 <- sum(g$prob * g$dep[, 1]) / sum(g$prob * (g$dep[, 1] > 0))
  data.frame(survey_year = year, scenario = sc, label = scenarios[[sc]]$label,
             takeup = takeup, avg_deposit_y1 = avg1,
             target_avg_deposit_y1 = target_avg,
             first_year_cost = p$gov_first_year_infants / p$gov_takeup * takeup * avg1,
             gov_first_year_cost = p$gov_first_year_cost,
             universal_y1 = g$universal[1], universal_total = sum(g$universal),
             share_above_floor = mean(above), s = if (sc == "A") NA else s,
             k = if (sc == "B") k else NA,
             floor_eq = floor_eq, floor_household_y1 = floor_t(1),
             save_share_year = save_year)
}))
write.csv(calib, file.path(out_dir, "account_calibration.csv"), row.names = FALSE)

universal <- do.call(rbind, lapply(names(scenarios), function(sc) {
  data.frame(survey_year = year, scenario = sc, t = tt, calendar_year = p$first_deposit_year + tt - 1,
             cap = caps, universal = grid_results[[sc]]$universal)
}))
write.csv(universal, file.path(out_dir, "account_universal.csv"), row.names = FALSE)

# ---- Families at chosen percentiles ------------------------------------------------------

points <- data.frame(point = c("P10", "P25", "P50", "P75", "P90", "median_real"),
                     u = c(0.10, 0.25, 0.50, 0.75, 0.90, NA))
points$eq <- ifelse(is.na(points$u), type_median, qdagum(points$u, fa, fp, fb))
points$u[is.na(points$u)] <- pdagum(type_median, fa, fp, fb)

by_pct <- do.call(rbind, lapply(names(scenarios), function(sc) {
  S <- scenarios[[sc]]; g <- grid_results[[sc]]
  prob <- S$prob(points$eq); dep <- S$dep(points$eq)
  do.call(rbind, lapply(names(returns), function(rn) {
    r <- returns[[rn]]
    state_fv <- as.vector(dep %*% fv_factors(years, r))
    uni_fv <- sum(g$universal * fv_factors(years, r))
    data.frame(survey_year = year, scenario = sc, return_case = rn, r = r, point = points$point,
               u = points$u, eq_income = points$eq,
               household_income = points$eq * scale, household_income_y1 = hh_income(points$eq, 1),
               floor_household_y1 = floor_t(1), prob = prob,
               deposit_y1 = dep[, 1], deposit_y1_share = dep[, 1] / hh_income(points$eq, 1),
               parent_total = rowSums(dep), state_total = rowSums(dep),
               value_18 = 2 * state_fv, state_value_18 = state_fv,
               returns_18 = 2 * state_fv - 2 * rowSums(dep),
               value_18_real = real_value(2 * state_fv, p), state_value_18_real = real_value(state_fv, p),
               expected_state_18 = prob * state_fv, universal_state_18 = uni_fv,
               universal_state_18_real = real_value(uni_fv, p))
  }))
}))
write.csv(by_pct, file.path(out_dir, "account_by_percentile.csv"), row.names = FALSE)

# ---- Quintiles of the household type, inequality measures ------------------------------

qn <- ceiling(u * 5)
by_q <- do.call(rbind, lapply(names(scenarios), function(sc) {
  g <- grid_results[[sc]]
  exp_state <- g$prob * g$state_fv[, "main"]
  uni <- sum(g$universal * fv_factors(years, returns[["main"]]))
  # A taking-part family's account at 18 holds parental and state money plus returns (2 x state).
  part <- g$prob * (g$dep[, 1] > 0)
  total <- 2 * g$state_fv[, "main"]
  part_q <- tapply(part, qn, sum)
  data.frame(survey_year = year, scenario = sc, quintile = 1:5,
             eq_income_mean = tapply(eq_grid, qn, mean),
             household_income_mean = tapply(eq_grid * scale, qn, mean),
             takeup = tapply(part, qn, mean),
             total_18_if_part = ifelse(part_q > 0, tapply(part * total, qn, sum) / part_q, NA),
             expected_total_18 = tapply(part * total, qn, mean),
             expected_state_18 = tapply(exp_state, qn, mean),
             share_of_state = tapply(exp_state, qn, sum) / sum(exp_state),
             universal_state_18 = uni)
}))
write.csv(by_q, file.path(out_dir, "account_by_quintile.csv"), row.names = FALSE)

ineq <- do.call(rbind, lapply(names(scenarios), function(sc) {
  g <- grid_results[[sc]]
  v <- g$state_fv[, "main"]
  exp_state <- g$prob * v
  # Realised state money: a family deposits (value v) with probability prob, else 0.
  real_x <- c(v, rep(0, n)); real_w <- c(g$prob, 1 - g$prob)
  uni <- sum(g$universal * fv_factors(years, returns[["main"]]))
  data.frame(survey_year = year, design = c(paste0("match_", sc), paste0("universal_", sc)),
             scenario = sc,
             # children whose expected state money under matching is below the universal amount
             share_better_universal = c(mean(exp_state < uni), NA),
             # realised: a child ends up with v if its family deposits, else with nothing
             share_better_universal_realised = c(1 - sum(g$prob * (v > uni)) / n, NA),
             concentration_index = c(concentration_index(exp_state, u), 0),
             share_bottom40 = c(sum(exp_state[u <= 0.4]) / sum(exp_state), 0.4),
             share_top40 = c(sum(exp_state[u > 0.6]) / sum(exp_state), 0.4),
             gini_state_18 = c(gini_weighted(real_x, real_w), 0),
             share_children_with_state = c(sum(g$prob * (g$dep[, 1] > 0)) / n, 1),
             mean_state_18 = c(mean(exp_state), uni),
             income_gini = gini_dagum(fa, fp))
}))

# Sensitivity: families with a baby probably sit lower than all couples with a
# dependent child (who include students up to 24). Shift the distribution so
# that its median equals the national median of children under 6, keeping the
# behavioural parameters of scenario B.
shift <- lt6_median / type_median
eq_sh <- eq_grid * shift
prob_sh <- scenarios$B$prob(eq_sh); dep_sh <- scenarios$B$dep(eq_sh)
v_sh <- as.vector(dep_sh %*% fv_factors(years, returns[["main"]]))
exp_sh <- prob_sh * v_sh
ineq <- rbind(ineq, data.frame(
  survey_year = year, design = "match_B_shifted", scenario = "B", share_better_universal = NA,
  share_better_universal_realised = NA,
  concentration_index = concentration_index(exp_sh, u),
  share_bottom40 = sum(exp_sh[u <= 0.4]) / sum(exp_sh), share_top40 = sum(exp_sh[u > 0.6]) / sum(exp_sh),
  gini_state_18 = gini_weighted(c(v_sh, rep(0, n)), c(prob_sh, 1 - prob_sh)),
  share_children_with_state = mean(prob_sh * (dep_sh[, 1] > 0)),
  mean_state_18 = mean(exp_sh), income_gini = gini_dagum(fa, fp)))
ineq$shift_median <- ifelse(ineq$design == "match_B_shifted", lt6_median, type_median)
write.csv(ineq, file.path(out_dir, "account_inequality.csv"), row.names = FALSE)

# ---- Account paths and concentration curves ------------------------------------------------

paths <- do.call(rbind, lapply(c("P25", "P50", "P75"), function(pt) {
  eq <- points$eq[points$point == pt]
  dep <- as.vector(scenarios$B$dep(eq))
  data.frame(survey_year = year, scenario = "B", point = pt, t = c(0, tt),
             calendar_year = p$first_deposit_year + c(0, tt) - 1,
             deposits_cum = c(0, cumsum(2 * dep)),
             balance = c(0, account_path(2 * dep, returns[["main"]])))
}))
write.csv(paths, file.path(out_dir, "account_paths.csv"), row.names = FALSE)

conc <- do.call(rbind, lapply(names(scenarios), function(sc) {
  g <- grid_results[[sc]]
  cc <- concentration_curve(g$prob * g$state_fv[, "main"], u)
  cc <- cc[c(1, seq(10, nrow(cc), by = 10)), ]
  data.frame(survey_year = year, scenario = sc, cc)
}))
write.csv(conc, file.path(out_dir, "account_concentration.csv"), row.names = FALSE)

message(sprintf("scenario B: s = %.4f, k = %.4f; universal year 1 = %.0f EUR", s, k, grid_results$B$universal[1]))
