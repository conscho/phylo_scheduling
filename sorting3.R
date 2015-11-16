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
    geom_boxplot() + 
    ggplotTheme + ggplotTitle + ggplotRotateLabel
  ggsave(file=paste(graphFileName, " sorting1", ".pdf" , sep = ""), plot = gp, w=10, h=10)
  
  
}

sumData <- totalComparison %>%
  group_by(sort) %>%
  summarise(mean_distance = mean(distance))

textData <- sumData %>%
  summarise(percentage = (round(max(mean_distance)/min(mean_distance), 4) - 1) * 100, mean_distance = mean(mean_distance))
  
gp = ggplot(sumData, aes(sort, mean_distance)) + 
  xlab("Sorting technique") + ylab("PLF-C Distance between consecutive sites") +
  geom_bar(stat = "identity") + 
  geom_text(data = textData, aes(x=1, y=mean_distance, label = paste(percentage, " % difference"))) +
  ggplotTheme #+ ggplotRotateLabel
ggsave(file=paste("graphs/sorting1 summary", ".pdf" , sep = ""), plot = gp, w=7, h=5)