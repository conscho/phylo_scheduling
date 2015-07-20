library(ggplot2)
library(grid)
library(dplyr)

ggplotTheme = theme(plot.margin = unit(c(1,1,1,1), "lines"), plot.title = element_text(size = rel(0.9)))
ggplotRotateLabel = theme(axis.text.x = element_text(angle = 90, hjust = 1))

files <- list.files("output", pattern = "*parameters.csv", full.names = TRUE)
for (parameter.file in files) {
  
  programParameters = read.csv(parameter.file)
  
  # Initialize
  graphFileName = programParameters[1, "graph_file_name"]
  parametersTitle = paste("Data folder:", programParameters[1, "data_folder"], "Number of partitions:", programParameters[1, "number_of_partitions"],
                          "Number of taxa:", programParameters[1, "number_of_taxa"], "Number of sites:", programParameters[1, "number_of_sites"],
                          "\nSample root:", programParameters[1, "sample_root"], "Sample trees:", programParameters[1, "sample_trees"],
                          "\nCompare with likelihood:", programParameters[1, "compare_with_likelihood"],
                          "Height analysis:", programParameters[1, "height_analysis"], "Split partitions:", programParameters[1, "split_partitions"],
                          "\nProgram runtime:", programParameters[1, "program_runtime"],
                          "Number of processes:", programParameters[1, "number_of_processes"], sep = " ")
  
  
  # Read Data, aggregate and subset
  rawData = read.csv(paste(programParameters[1, "data_file"]))
  
  subsetRawData <- filter(rawData, split_partitions == 0) # For values without splitted partitions
  
  aggregatedData <- aggregate(subsetRawData[c("operations_maximum","operations_optimized")], by=subsetRawData[c("tree","batch","likelihood","root_node","height")], FUN=mean)
  aggregatedData$operations_ratio <- (aggregatedData$operations_optimized / aggregatedData$operations_maximum)
  
  splitData <- aggregate(rawData["operations_optimized"], by=rawData[c("operations_maximum", "tree", "batch", "root_node", "partition")], FUN=diff)
  splitData$ratio_split_loss <- (abs(splitData$operations_optimized) / splitData$operations_maximum * 100)
  
  
  # Generate graphs
  ggplotTitle = ggtitle(paste("Boxplot: Ratio per batch\n", parametersTitle))
  gp = ggplot(aggregatedData, aes(batch, operations_ratio)) + geom_boxplot() + ggplotTheme + ggplotTitle
  ggsave(file=paste(graphFileName, " ratio per batch", ".pdf" , sep = ""), plot = gp, w=10, h=7)
  
  ggplotTitle = ggtitle(paste("Scatterplot: Likelihood to Ratio\n", parametersTitle))
  gp = ggplot(aggregatedData, aes(likelihood, operations_ratio, color=batch)) + geom_point(shape=19, alpha=1/4) + geom_smooth(method=lm) + ggplotTheme + ggplotTitle
  ggsave(file=paste(graphFileName, " likelihood to ratio", ".pdf" , sep = ""), plot = gp, w=10, h=7)
  
  ggplotTitle = ggtitle(paste("Scatterplot: height to ratio\n", parametersTitle))
  gp = ggplot(aggregatedData, aes(height, operations_ratio, color=batch)) + geom_point(shape=19, alpha=1/4) + ggplotTheme + ggplotTitle
  ggsave(file=paste(graphFileName, " height to ratio", ".pdf" , sep = ""), plot = gp, w=10, h=7)
  
  ggplotTitle = ggtitle(paste("Boxplot: Comparison of partitions for each tree\n", parametersTitle))
  gp = ggplot(subsetRawData, aes(partition, operations_ratio, color=batch)) + ggplotRotateLabel + geom_boxplot() + ggplotTheme + ggplotTitle
  ggsave(file=paste(graphFileName, " ratio of partitions per batch", ".pdf" , sep = ""), plot = gp, w=10, h=7)
  
  ggplotTitle = ggtitle(paste("Boxplot: Comparison splitted vs. unsplitted ratios per partition\n", parametersTitle))
  gp = ggplot(rawData, aes(partition, operations_ratio, color=factor(split_partitions))) + ggplotRotateLabel + geom_boxplot() + ggplotTheme + ggplotTitle
  ggsave(file=paste(graphFileName, " ratio of un-splitted partitions", ".pdf" , sep = ""), plot = gp, w=10, h=7)
  
  ggplotTitle = ggtitle(paste("Boxplot: Ratio loss due to partition split per partition\n", parametersTitle))
  gp = ggplot(splitData, aes(partition, ratio_split_loss)) + geom_boxplot(alpha=0.5, color="gray") + ggplotRotateLabel + geom_jitter(alpha=0.1, aes(color=batch), position = position_jitter(width = 0.05)) + ggplotTheme + ggplotTitle
  ggsave(file=paste(graphFileName, " ratio loss due to split per partition", ".pdf" , sep = ""), plot = gp, w=10, h=7)
  
  ggplotTitle = ggtitle(paste("Boxplot: Ratio loss due to partition split per batch including mean (red dot)\n", parametersTitle))
  gp = ggplot(splitData, aes(batch, ratio_split_loss)) + stat_summary(fun.y=mean, colour="red", geom="point", size = 3) + geom_boxplot(alpha=0.5, color="gray") + geom_jitter(alpha=0.1, position = position_jitter(width = 0.05)) + ggplotTheme + ggplotTitle
  ggsave(file=paste(graphFileName, " ratio loss due to split per batch", ".pdf" , sep = ""), plot = gp, w=10, h=7)
  
}
