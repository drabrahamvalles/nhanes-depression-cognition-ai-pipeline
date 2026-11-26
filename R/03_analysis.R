library(dplyr)
library(gtsummary)
library(survey)

nhanes_clean <- readRDS("data/nhanes_clean.rds")
outcomes <- c(
  cerad_learning = "CERAD learning",
  cerad_delayed_recall = "CERAD delayed recall",
  animal_fluency = "Animal fluency",
  dsst = "Digit Symbol Substitution Test"
)

mec_data <- nhanes_clean[nhanes_clean$mec_sample, ] |>
  mutate(
    # gtsummary requires an unordered grouping factor.
    phq9_category = factor(phq9_category, levels = levels(phq9_category), ordered = FALSE),
    sex = factor(RIAGENDR, levels = c(1, 2), labels = c("Male", "Female")),
    education = factor(
      DMDEDUC2, levels = 1:5,
      labels = c(
        "Less than 9th grade", "9th–12th grade, no diploma",
        "High school graduate or GED", "Some college or associate degree",
        "College graduate or above"
      )
    ),
    race_ethnicity = factor(
      RIDRETH3, levels = c(1, 2, 3, 4, 6, 7),
      labels = c(
        "Mexican American", "Other Hispanic", "Non-Hispanic White",
        "Non-Hispanic Black", "Non-Hispanic Asian", "Other or multiracial"
      )
    )
  )

# Build the full MEC design for domain variance estimation.
mec_design <- svydesign(
  ids = ~SDMVPSU,
  strata = ~SDMVSTRA,
  weights = ~wtmec4yr,
  data = mec_data,
  nest = TRUE
)
analytic_design <- subset(mec_design, analytic_sample)
n_analytic <- nrow(analytic_design$variables)
stopifnot(n_analytic == sum(nhanes_clean$analytic_sample))

table_1 <- analytic_design |>
  tbl_svysummary(
    by = phq9_category,
    include = c(RIDAGEYR, sex, education, race_ethnicity, all_of(names(outcomes))),
    label = c(
      list(RIDAGEYR = "Age (years)", sex = "Sex",
           education = "Education", race_ethnicity = "Race and ethnicity"),
      as.list(outcomes)
    ),
    type = list(c(RIDAGEYR, all_of(names(outcomes))) ~ "continuous",
                all_of(c("sex", "education", "race_ethnicity")) ~ "categorical"),
    statistic = list(
      all_continuous() ~ "{mean} ({sd})",
      all_categorical() ~ "{n_unweighted} ({p}%)"
    ),
    missing_text = "Missing score (unweighted n)",
    missing_stat = "{N_miss_unweighted}"
  ) |>
  modify_header(label = "Characteristic", all_stat_cols() ~ "{level} (n = {n_unweighted})") |>
  as_tibble()

regression_rows <- list()
figure_rows <- list()

for (outcome in names(outcomes)) {
  # Define a complete-score domain for each test.
  outcome_formula <- reformulate(outcome)
  outcome_design <- subset(analytic_design, !is.na(analytic_design$variables[[outcome]]))
  model_formula <- reformulate(c("phq9", "RIDAGEYR", "sex", "education", "race_ethnicity"),
                               response = outcome)
  model <- svyglm(model_formula, design = outcome_design)
  n_used <- nrow(outcome_design$variables)
  stopifnot(nobs(model) == n_used)

  phq9_result <- coef(summary(model))["phq9", ]
  beta <- unname(phq9_result["Estimate"])
  # Use the same residual degrees of freedom for the Wald interval and t test.
  margin <- qt(0.975, df = df.residual(model)) * unname(phq9_result["Std. Error"])
  regression_rows[[outcome]] <- tibble(
    test = outcomes[[outcome]],
    beta = beta,
    ci_low = beta - margin,
    ci_high = beta + margin,
    p = unname(phq9_result["Pr(>|t|)"]),
    n = n_used
  )

  group_means <- svyby(outcome_formula, ~phq9_category, outcome_design, svymean)
  group_intervals <- confint(group_means, df = degf(outcome_design))
  figure_rows[[outcome]] <- tibble(
    test = outcomes[[outcome]],
    phq9_category = group_means$phq9_category,
    mean = group_means[[outcome]],
    ci_low = group_intervals[, 1],
    ci_high = group_intervals[, 2]
  )
}

regression_results <- bind_rows(regression_rows)
regression_display <- regression_results |>
  mutate(p = if_else(p < 0.001, "< 0.001", sprintf("%.3f", p)))
cognitive_means <- bind_rows(figure_rows) |>
  mutate(test = factor(test, levels = unname(outcomes)))

dir.create("output", showWarnings = FALSE)
saveRDS(table_1, "output/table_1.rds")
write.csv(table_1, "output/table_1.csv", row.names = FALSE, na = "", fileEncoding = "UTF-8")
saveRDS(regression_results, "output/regression_results.rds")
# Export numeric p-values so the CSV retains precision for reuse.
write.csv(regression_results, "output/regression_results.csv", row.names = FALSE,
          fileEncoding = "UTF-8")
saveRDS(cognitive_means, "data/cognitive_means.rds")

n_initial <- nrow(nhanes_clean)
n_age60plus <- sum(nhanes_clean$age60plus)
n_age60plus_mec <- sum(mec_data$age60plus)
cat(
  "Initial sample: ", n_initial, "\n",
  "  Excluded below age 60: ", n_initial - n_age60plus, "\n",
  "Age 60 or older: ", n_age60plus, "\n",
  "  Excluded with zero weight or incomplete design: ", n_age60plus - n_age60plus_mec, "\n",
  "  Excluded with incomplete PHQ-9 or covariates: ", n_age60plus_mec - n_analytic, "\n",
  "Analytic base sample: ", n_analytic, "\n",
  sep = ""
)
print(as.data.frame(mutate(regression_display, missing_score = n_analytic - n)),
      row.names = FALSE)
