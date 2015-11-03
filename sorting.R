library(ggplot2)
library(grid)
library(dplyr)



ggplotTheme = theme(plot.margin = unit(c(1,1,1,1), "lines"), plot.title = element_text(size = rel(0.9)))
ggplotRotateLabel = theme(axis.text.x = element_text(angle = 90, hjust = 1))


files <- list.files("output_sorting", pattern = "*parameters.csv", full.names = TRUE)
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
  
  
  
  
  # Generate graph
  ggplotTitle = ggtitle(paste("Barchart sorting: Comparison of sorting MSA", parametersTitle))
  gp = ggplot(rawData, aes(x=reorder(sort, distance), y=distance)) + 
    xlab("Sorting technique") +
    #geom_blank(aes(y=graph_points*1.1), position = "stack") + ## Dirty hack to increase upper boundary of y-axis 
    #geom_rect(data = subset(sumData, op_optimized == min(sumData$op_optimized)), aes(xmin = -Inf, ymin = -Inf, xmax = +Inf, ymax = Inf), fill = "green", alpha = 30/100) + 
    geom_bar(stat = "identity") + 
    #geom_text(aes(label=graph_points, bin, graph_points), position="stack", vjust = +1, size=2) + 
    #geom_text(aes(0, op_optimized, label=paste("largest bin:\n", "operations: ", op_optimized, "\n", "savings: ", savings, "%", "\n", "splits: ", splits, sep=""), group=NULL), data=sumData, vjust=-0.3, hjust=0.1/max(combData$bin), color = "red", size=3) + 
    #geom_line(aes(x=bin, y=lower_bound), color="red", data=rawData) +
    facet_wrap(~partition, ncol = 1, scales = "free_y") + 
    ggplotTheme + ggplotTitle + ggplotRotateLabel
  ggsave(file=paste(graphFileName, " sorting", ".pdf" , sep = ""), plot = gp, w=10, h=15)
  
  
  
}