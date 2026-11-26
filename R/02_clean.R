library(dplyr)
library(tidyr)

nhanes_tables <- readRDS("data/nhanes_raw.rds")
cycle_labels <- c(G = "2011–2012", H = "2013–2014")
demo_columns <- c(
  "SEQN", "RIDAGEYR", "RIAGENDR", "DMDEDUC2", "RIDRETH3",
  "SDMVPSU", "SDMVSTRA", "WTMEC2YR"
)
phq_items <- sprintf("DPQ%03d", seq(10, 90, by = 10))
cerad_trials <- c("CFDCST1", "CFDCST2", "CFDCST3")
cognition_columns <- c(
  "SEQN", cerad_trials, "CFDCSR", "CFDAST", "CFDDS",
  "CFASTAT", "CFDCCS", "CFDAPP", "CFDDPP"
)

# Require unique participant IDs to avoid duplicating records in joins.
for (table_name in names(nhanes_tables)) {
  ids <- nhanes_tables[[table_name]]$SEQN
  if (anyNA(ids) || anyDuplicated(ids) > 0L) {
    stop("Missing or duplicate SEQN in ", table_name, call. = FALSE)
  }
}

cycle_data <- vector("list", length(cycle_labels))
names(cycle_data) <- names(cycle_labels)

for (suffix in names(cycle_labels)) {
  demo <- select(nhanes_tables[[paste0("DEMO_", suffix)]], all_of(demo_columns))
  dpq <- select(nhanes_tables[[paste0("DPQ_", suffix)]], SEQN, all_of(phq_items))
  cfq <- select(nhanes_tables[[paste0("CFQ_", suffix)]], all_of(cognition_columns))

  # DEMO defines the initial sample regardless of assessment completion.
  cycle_data[[suffix]] <- demo |>
    left_join(dpq, by = "SEQN") |>
    left_join(cfq, by = "SEQN") |>
    mutate(cycle = cycle_labels[[suffix]])
}

nhanes_clean <- bind_rows(cycle_data) |>
  mutate(
    across(all_of(c(phq_items, "DMDEDUC2")), ~ replace(.x, .x %in% c(7, 9), NA)),
    # PHQ-9 and CERAD learning totals require complete items or trials.
    phq9 = rowSums(pick(all_of(phq_items))),
    phq9_category = cut(
      phq9, breaks = c(0, 5, 10, Inf), right = FALSE,
      labels = c("<5", "5–9", "≥10"), ordered_result = TRUE
    ),
    cerad_learning = rowSums(pick(all_of(cerad_trials))),
    cerad_delayed_recall = CFDCSR,
    animal_fluency = CFDAST,
    dsst = CFDDS,
    age60plus = !is.na(RIDAGEYR) & RIDAGEYR >= 60,
    # Divide the two-year MEC weight by two for the pooled cycles.
    wtmec4yr = WTMEC2YR / 2,
    mec_sample = !is.na(wtmec4yr) & wtmec4yr > 0 &
      !is.na(SDMVPSU) & !is.na(SDMVSTRA),
    # Assess cognitive score availability separately for each test.
    analytic_sample = age60plus & mec_sample &
      if_all(all_of(c("phq9", "RIAGENDR", "DMDEDUC2", "RIDRETH3")), ~ !is.na(.x))
  )

expected_n <- nrow(nhanes_tables$DEMO_G) + nrow(nhanes_tables$DEMO_H)
stopifnot(nrow(nhanes_clean) == expected_n, anyDuplicated(nhanes_clean$SEQN) == 0L)

sample_counts <- nhanes_clean |>
  summarise(
    n_initial = n(),
    n_age60plus = sum(age60plus),
    n_zero_weight = sum(WTMEC2YR == 0, na.rm = TRUE),
    n_age60plus_zero_weight = sum(age60plus & WTMEC2YR == 0, na.rm = TRUE),
    n_age60plus_missing_design = sum(age60plus & (
      is.na(WTMEC2YR) | is.na(SDMVPSU) | is.na(SDMVSTRA)
    )),
    n_age60plus_missing_phq9 = sum(age60plus & is.na(phq9)),
    n_analytic_base = sum(analytic_sample)
  )

test_counts <- nhanes_clean |>
  select(age60plus, analytic_sample, cerad_learning, cerad_delayed_recall, animal_fluency, dsst) |>
  pivot_longer(c(cerad_learning, cerad_delayed_recall, animal_fluency, dsst),
               names_to = "test", values_to = "score") |>
  summarise(
    n_missing_age60plus = sum(age60plus & is.na(score)),
    n_analytic = sum(analytic_sample & !is.na(score)),
    .by = test
  )

saveRDS(nhanes_clean, "data/nhanes_clean.rds")
print(as.data.frame(sample_counts), row.names = FALSE)
print(as.data.frame(test_counts), row.names = FALSE)
