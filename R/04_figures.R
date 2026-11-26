library(ggplot2)

cognitive_means <- readRDS("data/cognitive_means.rds")
dir.create("figures", showWarnings = FALSE)

plot_scores <- function(scores) {
  ggplot(scores, aes(phq9_category, mean, ymin = ci_low, ymax = ci_high)) +
    geom_pointrange(colour = "#14646C", linewidth = 0.65) +
    # Use separate y scales for tests with different score ranges.
    facet_wrap(vars(test), nrow = 1, scales = "free_y") +
    labs(
      x = "PHQ-9 score category",
      y = "Weighted mean score (95% CI)",
      subtitle = "Adults aged 60 years or older, NHANES 2011–2014"
    ) +
    theme_minimal(base_size = 12) +
    theme(
      panel.grid.minor = element_blank(),
      panel.grid.major.x = element_blank(),
      panel.spacing = grid::unit(1.2, "lines"),
      strip.text = element_text(face = "bold"),
      plot.subtitle = element_text(margin = margin(b = 10))
    )
}

cerad_scores <- subset(cognitive_means, test %in% c("CERAD learning", "CERAD delayed recall"))
other_scores <- subset(cognitive_means, test %in% c("Animal fluency", "Digit Symbol Substitution Test"))

ggsave("figures/cerad_by_phq9.png", plot_scores(cerad_scores),
       device = ragg::agg_png,
       width = 8, height = 3.8, units = "in", dpi = 300, bg = "white")
ggsave("figures/fluency_dsst_by_phq9.png", plot_scores(other_scores),
       device = ragg::agg_png,
       width = 8, height = 3.8, units = "in", dpi = 300, bg = "white")
