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
  
  
  # Generate graphs
  ggplotTitle = ggtitle(paste("Barchart: Site distribution to bins with operations\n", parametersTitle))
  gp1 = ggplot(rawData, aes(x=bin, fill=partition)) + scale_x_discrete() + ggplotRotateLabel + geom_bar(aes(x=bin, y=operations), stat="identity", colour="black") + ggplotTheme + ggplotTitle
  
  ggplotTitle = ggtitle(paste("Barchart: Site distribution to bins\n", parametersTitle))
  gp2 = ggplot(rawData, aes(x=bin, fill=partition)) + scale_x_discrete() + ggplotRotateLabel + geom_bar() + geom_text(stat='bin', aes(label=..count..), vjust =-0.5, position = "stack") + ggplotTheme + ggplotTitle
  
  pdf(paste(graphFileName, " groundtruth", ".pdf" , sep = ""), w=10, h=10)
  grid.arrange(gp1, gp2, ncol=2)
  dev.off()
  
}





