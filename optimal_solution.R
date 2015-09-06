library(ggplot2)
library(grid)
library(dplyr)
library(gridExtra)


ggplotTheme = theme(plot.margin = unit(c(1,1,1,1), "lines"), plot.title = element_text(size = rel(0.9)))
ggplotRotateLabel = theme(axis.text.x = element_text(angle = 90, hjust = 1))


files <- list.files("output_optimal_solution", pattern = "*parameters.csv", full.names = TRUE)
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
  rawData$type <- "operations"
  rawData2 = read.csv(paste(programParameters[1, "data_file"]))
  rawData2$type <- "sites"
  rawData2$operations <- 1
  combData = rbind(rawData, rawData2)
  
  
  # Generate graphs
  ggplotTitle = ggtitle(paste("Barchart: Site distribution to bins with operations\n", parametersTitle))
  gp = ggplot(combData, aes(x=bin, ymax=operations, fill=partition)) + 
    scale_x_discrete(limit = 0:max(combData$bin)) + 
    geom_bar(aes(x=bin, y=operations), stat="identity", colour="black") + 
    geom_text(aes(label=operations, bin, operations), position="stack", vjust = +1) + 
    facet_grid(type~solution, scales = "free_y") + 
    ggplotRotateLabel + ggplotTheme + ggplotTitle
  ggsave(file=paste(graphFileName, " groundtruth", ".pdf" , sep = ""), plot = gp, w=10, h=10)
  
}





