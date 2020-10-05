suppressPackageStartupMessages({
  library(tidyverse)
  library(gglorenz)
})
args <- commandArgs(trailingOnly = TRUE)
project <- args[1]
kb_bin_width <- as.numeric(args[2])

chr_starts = c(0, 248956422, 491149951, 689445510, 879660065, 1061198324, 1232004303, 1391350276, 1536488912, 
               1674883629, 1808681051, 1943767673, 2077042982, 2191407310, 2298451028, 2400442217, 2490780562, 
               2574038003, 2654411288, 2713028904, 2777473071, 2824183054, 2875001522, 3031042417, 3088269832)
chr_names = c(paste("chr", paste(seq(1, 22)), sep = ""))
ggplot_theme<- theme(axis.line.y = element_line(size=.1,color = "black"), axis.line.x = element_line(size=.1,color = "black"),
                     axis.text.x = element_text(angle = 45, hjust = 1, size=10, lineheight=0.2, color="black"),
                     panel.grid.major = element_line(color = "black"), panel.background = element_rect(fill="white"),
                     panel.grid.major.x = element_line(size=.1, color="grey"), panel.grid.major.y = element_blank(), 
                     plot.title = element_text(size=15), legend.text=element_text(size=8))

df <- read_tsv(sprintf("%s.binned_coverage.tsv", project)) %>%
  group_by(chr, start) %>%
  mutate(abs_start = chr_starts[which(chr_names == chr)] + start) %>%
  ungroup() %>%
  select(-chr, -start, -end)
fig <- ggplot(df, aes(x = coverage, color = sample)) + 
  stat_lorenz() + ggplot_theme + annotate_ineq(df$coverage) +
  labs(title = sprintf("%s coverage inquality - %skb bins", project, kb_bin_width), x = "Cumulative fraction of genome", y = "Cumulative fraction of total reads")
ggsave(sprintf("%s.%skb_bins_lorenz_curve.pdf", project, kb_bin_width), fig, width = 11, height = 8)