library(ggplot2)
library(grid)
library(dplyr)



ggplotTheme = theme(plot.margin = unit(c(1,1,1,1), "lines"), plot.title = element_text(size = rel(0.9)))
ggplotRotateLabel = theme(axis.text.x = element_text(angle = 90, hjust = 1, vjust = 0.5))

# Init for total comparison of heuristics
totalComparison = data_frame()


files <- list.files("output_sorting1", pattern = "*parameters.csv", full.names = TRUE)
for (parameter.file in files) {
  
  programParameters = read.csv(parameter.file)
  
  # Initialize
  graphFileName = programParameters[1, "graph_file_name"]
  parametersTitle = ""
  for (parameterName in names(programParameters)) {
    parametersTitle <- paste(parametersTitle,(paste(parameterName, programParameters[1, parameterName], sep=": ")), sep = "\n")
  }
  
  # Read and aggregate data
  rawData = read.csv(paste(programParameters[1, "data_file"]))
  
  # Overall summary
  rawData$fileName <- graphFileName
  totalComparison <- rbind(totalComparison, rawData)
  
  
  # Generate graph
  ggplotTitle = ggtitle(paste("Boxplot sorting: Comparison of MSA sorting per tree", parametersTitle))
  gp = ggplot(rawData, aes(x=sort, y=distance)) + 
    xlab("Sorting technique") + ylab("PLF-C Distance between consecutive sites") +
    #geom_blank(aes(y=graph_points*1.1), position = "stack") + ## Dirty hack to increase upper boundary of y-axis 
    #geom_rect(data = subset(sumData, op_optimized == min(sumData$op_optimized)), aes(xmin = -Inf, ymin = -Inf, xmax = +Inf, ymax = Inf), fill = "green", alpha = 30/100) + 
    geom_boxplot(aes(fill=batch)) + 
    #geom_text(aes(label=graph_points, bin, graph_points), position="stack", vjust = +1, size=2) + 
    #geom_text(aes(0, op_optimized, label=paste("largest bin:\n", "operations: ", op_optimized, "\n", "savings: ", savings, "%", "\n", "splits: ", splits, sep=""), group=NULL), data=sumData, vjust=-0.3, hjust=0.1/max(combData$bin), color = "red", size=3) + 
    #geom_line(aes(x=bin, y=lower_bound), color="red", data=rawData) +
    #facet_wrap(~partition, ncol = 1, scales = "free_y") + 
    ggplotTheme + ggplotTitle + ggplotRotateLabel
  ggsave(file=paste(graphFileName, " sorting1", ".pdf" , sep = ""), plot = gp, w=10, h=10)
  
  
}

sumData <- totalComparison %>%
  group_by(sort) %>%
  summarise(mean_distance = mean(distance))

textData <- sumData %>%
  summarise(percentage = (round(max(mean_distance)/min(mean_distance), 4) - 1) * 100, mean_distance = mean(mean_distance))
  
gp = ggplot(sumData, aes(sort, mean_distance)) + 
  xlab("Batch") + ylab("Accumulated PLF-C of consecutive sites") +
  geom_bar(stat="identity", position = "dodge") + 
  geom_text(data = textData, aes(x=1, y=mean_distance, label = paste(percentage, " % difference"))) +
  ggplotTheme + ggplotRotateLabel
ggsave(file=paste("graphs/sorting1 summary", ".pdf" , sep = ""), plot = gp, w=6, h=5)