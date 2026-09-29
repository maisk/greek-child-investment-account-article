# The child investment account ("Επενδυτικός λογαριασμός για τη νέα γενιά"):
# state matching schedule, account value at 18, a parental deposit rule, and
# inequality measures for the resulting state money. Base R only.
#
# Conventions
#   - Account year t = 1..years; calendar year = first_deposit_year + t - 1.
#   - Deposits are made during the year and earn half a year's return in that
#     year: balance_t = balance_{t-1} * (1 + r) + deposit_t * (1 + r)^0.5.
#     This reproduces the official 77.062 EUR at 5% exactly (64.128 EUR at 3%
#     against an official 64.109 EUR).
#   - Parents deposit at most the matching cap: the state money, which is what
#     the inequality question is about, is then equal to the parental deposit.

read_policy <- function(path = "data/policy_parameters.csv") {
  p <- read.csv(path)
  setNames(as.list(p$value), p$parameter)
}

# Matching cap in account year t.
match_cap <- function(t, params) {
  params$match_cap * (1 + params$cap_step)^floor((t - 1) / params$cap_step_years)
}

# Balance after each year for a vector of yearly deposits.
account_path <- function(deposits, r) {
  bal <- numeric(length(deposits))
  b <- 0
  for (t in seq_along(deposits)) {
    b <- b * (1 + r) + deposits[t] * (1 + r)^0.5
    bal[t] <- b
  }
  bal
}

account_value <- function(deposits, r) {
  if (!length(deposits)) return(0)
  tail(account_path(deposits, r), 1)
}

# Future value factor of one euro deposited in each account year, so that the
# value at 18 of deposits d_t is sum(d_t * fv_factors(...)).
fv_factors <- function(years, r) (1 + r)^(years - seq_len(years) + 0.5)

# Euros at the end of the last account year expressed in euros of the birth year.
real_value <- function(x, params) {
  x / (1 + params$inflation)^(params$first_deposit_year + params$years - 1 - params$birth_year)
}

# Parental deposit rule: a share s of household income above a subsistence floor,
# up to the matching cap. y and floor are household net incomes in the deposit year.
parent_deposit <- function(y, floor, s, cap) pmin(cap, s * pmax(0, y - floor))

# ---- Inequality measures -------------------------------------------------------

# Gini of a discrete distribution with values x and weights w.
gini_weighted <- function(x, w = rep(1, length(x))) {
  o <- order(x); x <- x[o]; w <- w[o] / sum(w)
  mu <- sum(w * x)
  if (mu == 0) return(0)
  cw <- cumsum(w); cxw <- cumsum(w * x) / mu
  # Area under the Lorenz curve by trapezoids.
  area <- sum(w * (cxw + c(0, head(cxw, -1)))) / 2
  1 - 2 * area
}

# Concentration index of x across units ranked by income (rank in [0, 1] with
# weights w): > 0 means x goes disproportionately to richer units, 0 is neutral,
# < 0 means it favours poorer units.
concentration_index <- function(x, rank, w = rep(1, length(x))) {
  w <- w / sum(w)
  mu <- sum(w * x)
  if (mu == 0) return(0)
  2 * sum(w * (x - mu) * (rank - sum(w * rank))) / mu
}

# Concentration curve: cumulative share of x against cumulative population share,
# units ordered by income rank.
concentration_curve <- function(x, rank, w = rep(1, length(x))) {
  o <- order(rank); x <- x[o]; w <- w[o] / sum(w)
  data.frame(pop_share = c(0, cumsum(w)), x_share = c(0, cumsum(w * x) / sum(w * x)))
}
