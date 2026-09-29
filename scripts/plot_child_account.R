# Figures for article/02_child_account.qmd, drawn from the CSVs written by
# scripts/child_account.R.
#   Rscript scripts/plot_child_account.R [survey_year]
# Writes figures/account_{by_percentile,by_quintile,paths,concentration}_<year>.png.

library(ggplot2)
source("R/plot_helpers.R")

args <- commandArgs(trailingOnly = TRUE)
year <- if (length(args)) as.integer(args[1]) else 2025L
d <- function(f) { x <- read.csv(file.path("data/derived", f)); x[x$survey_year == year, ] }

pct_  <- read.csv("data/policy_parameters.csv")
param <- function(k) pct_$value[pct_$parameter == k]
r_main <- param("return_main")
by_pct <- d("account_by_percentile.csv")
by_q   <- d("account_by_quintile.csv")
paths  <- d("account_paths.csv")
conc   <- d("account_concentration.csv")
ineq   <- d("account_inequality.csv")
calib  <- d("account_calibration.csv")

k_eur_axis <- function(x) formatC(x / 1000, format = "d")
pct0 <- function(x) paste0(formatC(100 * x, format = "f", digits = 0), "%")
last_year <- param("first_deposit_year") + param("years") - 1
source_note <- sprintf(paste0(
  "Μοντέλο: κατανομή εισοδήματος για ζευγάρια με 1 παιδί (Eurostat, EU-SILC %d, εισοδήματα %d) × 1,8 για παιδί κάτω των 14.\n",
  "Απόδοση %s τον χρόνο, αύξηση εισοδημάτων %s τον χρόνο. Σενάριο Β: συμμετοχή κατά τη ροπή αποταμίευσης (ilc_odbt11), ",
  "κατάθεση %s του εισοδήματος πάνω από το όριο φτώχειας."),
  year, year - 1, pct0(r_main), pct0(param("income_growth")),
  paste0(formatC(100 * calib$s[calib$scenario == "B"], format = "f", digits = 1, decimal.mark = ","), "%"))

# ---- 1. Value at 18 by percentile, scenario B, for a family that takes part ---------

b <- by_pct[by_pct$scenario == "B" & by_pct$return_case == "main" & by_pct$point != "median_real", ]
b$point <- factor(b$point, levels = b$point)
parts <- rbind(
  data.frame(point = b$point, part = "Καταθέσεις γονέων", value = b$parent_total),
  data.frame(point = b$point, part = "Κρατική εισφορά", value = b$state_total),
  data.frame(point = b$point, part = "Αποδόσεις", value = b$returns_18))
parts$part <- factor(parts$part, levels = c("Αποδόσεις", "Κρατική εισφορά", "Καταθέσεις γονέων"))
uni <- unique(b$universal_state_18)
top <- max(b$value_18)
lab <- data.frame(point = b$point, y = b$value_18,
                  label = eur(round(b$value_18, -2)),
                  prob = sprintf("πιθανότητα συμμετοχής %s", pct0(b$prob)))

g1 <- ggplot(parts, aes(point, value, fill = part)) +
  geom_col(width = 0.62, colour = surface, linewidth = 0.5) +
  geom_hline(yintercept = uni, colour = ink, linewidth = 0.5, linetype = "22") +
  annotate("text", x = nrow(b) + 0.42, y = uni, hjust = 0, size = 3.1, colour = ink, lineheight = 0.95,
           label = sprintf("ίδιο ποσό\nγια κάθε παιδί:\n%s κρατικά\nχρήματα στα 18", eur(round(uni, -2)))) +
  geom_text(data = lab, aes(point, y, label = label), inherit.aes = FALSE, vjust = -0.4, size = 3.3,
            colour = ink, lineheight = 0.9) +
  geom_text(data = lab, aes(point, -0.045 * top, label = prob), inherit.aes = FALSE, size = 2.9,
            colour = ink_2) +
  scale_fill_manual(values = c("Καταθέσεις γονέων" = series[1], "Κρατική εισφορά" = series[2],
                               "Αποδόσεις" = series[3]), breaks = c("Καταθέσεις γονέων", "Κρατική εισφορά", "Αποδόσεις"),
                    name = NULL) +
  scale_x_discrete(labels = function(x) sprintf("%s\n%s", x, eur(round(b$household_income[match(x, b$point)], -2))),
                   expand = expansion(add = c(0.6, 1.25))) +
  scale_y_continuous(labels = k_eur_axis, expand = expansion(mult = c(0.06, 0.12))) +
  labs(title = sprintf("Τι έχει ο λογαριασμός στα 18 (%d), αν η οικογένεια συμμετέχει", last_year),
       subtitle = paste0("Ζευγάρι με 1 παιδί, σε διάφορα σημεία της κατανομής εισοδήματος (κάτω από κάθε στήλη: ",
                         "καθαρό εισόδημα νοικοκυριού ", year - 1, ").\n",
                         "Οι φτωχότερες οικογένειες καταθέτουν λιγότερα, άρα παίρνουν και λιγότερα από το κράτος. ",
                         "Κάτω από το όριο φτώχειας δεν καταθέτουν τίποτα."),
       x = "Σημείο της κατανομής (P10 = το 10% των οικογενειών έχει λιγότερα)", y = "Ονομαστική αξία (χιλ. €)",
       caption = source_note) +
  theme_chart + theme(legend.position = "top", legend.justification = "left",
                      legend.text = element_text(colour = ink_2, size = 10),
                      panel.grid.major.y = element_line(colour = grid_col, linewidth = 0.3))
save_chart(g1, sprintf("figures/account_by_percentile_%d.png", year))

# ---- 2. State money per child by income quintile: matching vs universal ------------

q <- by_q[by_q$scenario == "B", ]
bars <- rbind(
  data.frame(quintile = q$quintile, design = "Matching (σενάριο Β)", value = q$expected_state_18),
  data.frame(quintile = q$quintile, design = "Ίδιο ποσό για κάθε παιδί", value = q$universal_state_18))
bars$design <- factor(bars$design, levels = c("Matching (σενάριο Β)", "Ίδιο ποσό για κάθε παιδί"))
qlab <- c("Q1\nφτωχότερο 20%", "Q2", "Q3", "Q4", "Q5\nπλουσιότερο 20%")
iB <- ineq[ineq$design == "match_B", ]

g2 <- ggplot(bars, aes(factor(quintile), value, fill = design)) +
  geom_col(position = position_dodge(width = 0.72), width = 0.66, colour = surface, linewidth = 0.5) +
  geom_text(aes(label = eur(round(value, -2))), position = position_dodge(width = 0.72), vjust = -0.4,
            size = 3, colour = ink) +
  scale_fill_manual(values = c(series[2], series[1]), name = NULL) +
  scale_x_discrete(labels = qlab) +
  scale_y_continuous(labels = k_eur_axis, expand = expansion(mult = c(0, 0.12))) +
  labs(title = "Πόσα κρατικά χρήματα έχει κατά μέσο όρο ένα παιδί στα 18, ανά εισόδημα οικογένειας",
       subtitle = sprintf(paste0(
         "Ίδιος προϋπολογισμός και στα δύο σχέδια. Με το matching, το φτωχότερο 40%% των παιδιών παίρνει το %s ",
         "των κρατικών χρημάτων\nκαι το πλουσιότερο 40%% το %s. Με ίδιο ποσό για όλους, το %s των παιδιών θα έβγαινε κερδισμένο."),
         pct0(iB$share_bottom40), pct0(iB$share_top40), pct0(iB$share_better_universal_realised)),
       x = "Πεμπτημόριο εισοδήματος (ζευγάρια με 1 παιδί)", y = "Κρατικά χρήματα στα 18, με αποδόσεις (χιλ. €)",
       caption = source_note) +
  theme_chart + theme(legend.position = "top", legend.justification = "left",
                      legend.text = element_text(colour = ink_2, size = 10),
                      panel.grid.major.y = element_line(colour = grid_col, linewidth = 0.3))
save_chart(g2, sprintf("figures/account_by_quintile_%d.png", year))

# ---- 3. Account balance over the years, scenario B ---------------------------------

pl <- c(P25 = "P25", P50 = "P50 (διάμεσος)", P75 = "P75")
paths$label <- factor(pl[paths$point], levels = pl)
ends <- paths[paths$t == max(paths$t), ]

g3 <- ggplot(paths, aes(calendar_year, balance, colour = label)) +
  geom_line(linewidth = 0.9) +
  geom_point(data = ends, size = 2.4) +
  geom_text(data = ends, aes(label = sprintf("%s: %s", label, eur(round(balance, -2)))),
            hjust = -0.08, size = 3.3, colour = ink, show.legend = FALSE) +
  scale_colour_manual(values = series[c(1, 2, 3)], name = NULL) +
  scale_x_continuous(breaks = seq(2026, 2044, 2), expand = expansion(mult = c(0.01, 0.22))) +
  scale_y_continuous(labels = k_eur_axis) +
  labs(title = "Πώς μεγαλώνει ο λογαριασμός, για οικογένειες που συμμετέχουν",
       subtitle = "Υπόλοιπο στο τέλος κάθε έτους (καταθέσεις γονέων + κρατική εισφορά + αποδόσεις), ονομαστικά.",
       x = NULL, y = "Υπόλοιπο (χιλ. €)", caption = source_note) +
  theme_chart + theme(legend.position = "top", legend.justification = "left",
                      legend.text = element_text(colour = ink_2, size = 10),
                      panel.grid.major.y = element_line(colour = grid_col, linewidth = 0.3))
save_chart(g3, sprintf("figures/account_paths_%d.png", year))

# ---- 4. Concentration curves of state money ---------------------------------------------

cc <- conc[conc$scenario %in% c("B", "C"), ]
ci <- setNames(ineq$concentration_index, ineq$design)
ci_txt <- function(sc) formatC(ci[[paste0("match_", sc)]], format = "f", digits = 2, decimal.mark = ",")
lev <- c(B = sprintf("Matching, σενάριο Β · δείκτης συγκέντρωσης %s", ci_txt("B")),
         C = sprintf("Matching, σενάριο Γ (όλοι όσοι μπορούν) · δείκτης %s", ci_txt("C")))
cc$label <- factor(lev[cc$scenario], levels = lev)

g4 <- ggplot(cc, aes(pop_share, x_share, colour = label)) +
  geom_abline(slope = 1, intercept = 0, colour = ink_2, linewidth = 0.5, linetype = "22") +
  annotate("text", x = 0.34, y = 0.40, angle = 38, size = 3.1, colour = ink_2,
           label = "ίδιο ποσό για κάθε παιδί (και σενάριο Α)") +
  geom_line(linewidth = 0.9) +
  scale_colour_manual(values = series[c(2, 3)], name = NULL) +
  guides(colour = guide_legend(ncol = 1)) +
  scale_x_continuous(labels = function(v) paste0(100 * v, "%"), breaks = seq(0, 1, 0.2)) +
  scale_y_continuous(labels = function(v) paste0(100 * v, "%"), breaks = seq(0, 1, 0.2)) +
  coord_equal() +
  labs(title = "Σε ποιους πηγαίνουν τα κρατικά χρήματα",
       subtitle = paste0("Αθροιστικό μερίδιο των κρατικών χρημάτων, με τις οικογένειες σε σειρά από τη φτωχότερη στην πλουσιότερη.\n",
                         "Όσο πιο κάτω από τη διαγώνιο, τόσο περισσότερα πηγαίνουν στις πλουσιότερες. Δείκτης συγκέντρωσης:\n",
                         "0 = ίδιο ποσό για όλους, θετικός = υπέρ των πλουσιότερων, αρνητικός = υπέρ των φτωχότερων."),
       x = "Αθροιστικό ποσοστό οικογενειών (από τη φτωχότερη)", y = "Αθροιστικό μερίδιο κρατικών χρημάτων",
       caption = sub(" Σενάριο Β:", "\nΣενάριο Β:", source_note)) +
  theme_chart + theme(legend.position = "top", legend.justification = "left",
                      legend.text = element_text(colour = ink_2, size = 10),
                      panel.grid.major.x = element_line(colour = grid_col, linewidth = 0.3))
save_chart(g4, sprintf("figures/account_concentration_%d.png", year), width = 10, height = 8.5)

message("wrote account figures for ", year)
