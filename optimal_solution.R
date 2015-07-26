library(ggplot2)
library(grid)
library(dplyr)

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
  graphFileName = paste(programParameters[1, "graph_file_name"], " groundtruth", sep = "")
  counter = 1
  while (file.exists(paste(graphFileName, counter, ".pdf" , sep = ""))) {
    counter = counter + 1
  }
  
  ggplotTitle = ggtitle(paste("Barchart: Site distribution\n", parametersTitle))
  gp = ggplot(rawData, aes(x=bin, fill=partition)) + scale_x_discrete() + ggplotRotateLabel + geom_bar() + ggplotTheme + ggplotTitle
  ggsave(file=paste(graphFileName, counter, ".pdf" , sep = ""), plot = gp, w=10, h=10)

}
