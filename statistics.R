library(ggplot2)
library(grid)
library(dplyr)

ggplotTheme = theme(plot.margin = unit(c(1,1,1,1), "lines"), plot.title = element_text(size = rel(0.9)))
ggplotRotateLabel = theme(axis.text.x = element_text(angle = 90, hjust = 1, vjust = 0.5))

# Init for total summary of statistics
totalSummary = data_frame()

files <- list.files("output_statistics", pattern = "*parameters.csv", full.names = TRUE)
for (parameter.file in files) {
  
  programParameters = read.csv(parameter.file)
  
  # Initialize
  graphFileName = programParameters[1, "graph_file_name"]
  parametersTitle = ""
  for (parameterName in names(programParameters)) {
    parametersTitle <- paste(parametersTitle,(paste(parameterName, programParameters[1, parameterName], sep=": ")), sep = "\n")
  }
  
  
  # Read Data, aggregate and subset
  rawData = read.csv(paste(programParameters[1, "data_file"]))
  
  subsetRawData <- filter(rawData, split_partitions == 0) # For values without splitted partitions
  
  aggregatedData <- aggregate(subsetRawData[c("operations_maximum","operations_optimized")], by=subsetRawData[c("tree","batch","likelihood","root_node","height")], FUN=mean)
  aggregatedData$ratio_of_savings <- ((aggregatedData$operations_maximum - aggregatedData$operations_optimized) / aggregatedData$operations_maximum)
  
  splitData <- aggregate(rawData["operations_optimized"], by=rawData[c("operations_maximum", "tree", "batch", "root_node", "partition")], FUN=diff)
  splitData$ratio_split_loss <- (abs(splitData$operations_optimized) / splitData$operations_maximum * 100)
  
  
  # Generate graphs
  ggplotTitle = ggtitle(paste("Scatterplot: Likelihood to savings\n", parametersTitle))
  gp = ggplot(aggregatedData, aes(likelihood, ratio_of_savings, color=batch)) + geom_point(shape=19, alpha=1/4) + geom_smooth(method=lm) + ggplotTheme + ggplotTitle
  ggsave(file=paste(graphFileName, " likelihood to savings", ".pdf" , sep = ""), plot = gp, w=10, h=7)
  
  ggplotTitle = ggtitle(paste("Scatterplot: Height to savings\n", parametersTitle))
  gp = ggplot(aggregatedData, aes(height, ratio_of_savings, color=batch)) + geom_point(shape=19, alpha=1/4) + ggplotTheme + ggplotTitle
  ggsave(file=paste(graphFileName, " height to savings", ".pdf" , sep = ""), plot = gp, w=10, h=7)
  
  ggplotTitle = ggtitle(paste("Boxplot: Savings per batch\n", parametersTitle))
  gp = ggplot(aggregatedData, aes(batch, ratio_of_savings)) + geom_boxplot() + ggplotTheme + ggplotTitle
  ggsave(file=paste(graphFileName, " savings per batch", ".pdf" , sep = ""), plot = gp, w=10, h=7)
  
  ggplotTitle = ggtitle(paste("Boxplot: Savings per partition for each batch\n", parametersTitle))
  gp = ggplot(subsetRawData, aes(partition, ratio_of_savings, color=batch)) + ggplotRotateLabel + geom_boxplot() + ggplotTheme + ggplotTitle
  ggsave(file=paste(graphFileName, " savings per partition", ".pdf" , sep = ""), plot = gp, w=10, h=7)
  
  ggplotTitle = ggtitle(paste("Boxplot: Comparison splitted vs. unsplitted savings per partition\n", parametersTitle))
  gp = ggplot(rawData, aes(partition, ratio_of_savings, color=factor(split_partitions))) + ggplotRotateLabel + geom_boxplot() + ggplotTheme + ggplotTitle
  ggsave(file=paste(graphFileName, " split loss comparison per partition", ".pdf" , sep = ""), plot = gp, w=10, h=7)
  
  ggplotTitle = ggtitle(paste("Boxplot: Savings-ratio-loss due to partition split per partition\n", parametersTitle))
  gp = ggplot(splitData, aes(partition, ratio_split_loss)) + geom_boxplot(alpha=0.5, color="gray") + ggplotRotateLabel + geom_jitter(alpha=0.2, aes(color=batch), position = position_jitter(width = 0.05)) + ggplotTheme + ggplotTitle
  ggsave(file=paste(graphFileName, " split loss per partition", ".pdf" , sep = ""), plot = gp, w=10, h=7)
  
  ggplotTitle = ggtitle(paste("Boxplot: Savings-ratio-loss due to partition split per batch including mean (red dot)\n", parametersTitle))
  gp = ggplot(splitData, aes(batch, ratio_split_loss)) + geom_boxplot(alpha=0.5, color="gray") + geom_jitter(alpha=0.1, position = position_jitter(width = 0.05)) + stat_summary(fun.y=mean, colour="red", geom="point", size = 3) + ggplotTheme + ggplotTitle
  ggsave(file=paste(graphFileName, " splitt loss per batch", ".pdf" , sep = ""), plot = gp, w=10, h=7)
  
  
  # Collect data for total summary
  aggregatedData$fileName <- graphFileName
  totalSummary <- rbind(totalSummary, aggregatedData)
  
}


# Total summary of statistics
totalSummary = filter(totalSummary, batch %in% c("pars_ml", "rand_ml"))
totalSummary$ratio_of_savings = round(totalSummary$ratio_of_savings * 100, 2)

labelData <- totalSummary %>%
  group_by(batch) %>%
  mutate(note = (min(ratio_of_savings) == ratio_of_savings | max(ratio_of_savings) == ratio_of_savings)) %>%
  filter(note == TRUE) %>%
  distinct(ratio_of_savings)

# Generate graph
ggplotTitle = ggtitle(paste("Boxplot: Savings with the SR technique across all datasets"))
gp = ggplot(totalSummary, aes(x=batch, y=ratio_of_savings)) + 
  xlab("") + ylab("Percentage of savings") + 
  geom_boxplot() + 
  stat_summary(fun.y=mean, colour="red", geom="point", size=3, show_guide = FALSE) + 
  stat_summary(aes(label=round(..y.., 2)), fun.y=mean, geom="text", size=3, vjust = -0.5) +
  geom_text(data = labelData, aes(x = batch, y = ratio_of_savings, label = ratio_of_savings)) +
  ggplotTheme + ggplotTitle #+ ggplotRotateLabel
ggsave(file="graphs/summary of savings.pdf", plot = gp, w=8, h=6)