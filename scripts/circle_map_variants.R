suppressPackageStartupMessages({
  library(tidyverse)
})

args <- commandArgs(trailingOnly = TRUE)
variant_file <- args[1]
circle_file <- args[2]
output_file <- args[3]

variant_df <- read.delim(variant_file)
circle_df <- read.delim(circle_file, header = FALSE)

circle_variants_df <- data.frame()
for (row_num in 1:nrow(circle_df)) {
  row_chr <- circle_df[row_num, 1]
  row_start <- circle_df[row_num, 2]
  row_end <- circle_df[row_num, 3]
  new_variants <- filter(variant_df, CHROM == row_chr, POS > row_start, POS <= row_end)
  circle_variants_df <- rbind(circle_variants_df, new_variants)
}

circle_variants_df <- unique(circle_variants_df)
write_tsv(circle_variants_df, output_file)