library(nhanesA)

table_names <- c("DEMO_G", "DPQ_G", "CFQ_G", "DEMO_H", "DPQ_H", "CFQ_H")
nhanes_tables <- setNames(vector("list", length(table_names)), table_names)

for (table_name in table_names) {
  message("Downloading ", table_name)
  # Preserve the CDC response codes for recoding.
  nhanes_tables[[table_name]] <- nhanes(table_name, translated = FALSE)
  table <- nhanes_tables[[table_name]]

  if (!is.data.frame(table) || nrow(table) == 0L || !"SEQN" %in% names(table)) {
    stop("No usable data returned for ", table_name, call. = FALSE)
  }
}

# Save after all six downloads succeed so cleaning starts from a complete set.
dir.create("data", showWarnings = FALSE)
saveRDS(nhanes_tables, "data/nhanes_raw.rds")
