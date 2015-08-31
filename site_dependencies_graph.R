library(ggplot2)
library(grid)
library(dplyr)
library(igraph)

ggplotTheme = theme(plot.margin = unit(c(1,1,1,1), "lines"), plot.title = element_text(size = rel(0.9)))
ggplotRotateLabel = theme(axis.text.x = element_text(angle = 90, hjust = 1))


files <- list.files("output_site_dependencies_graph", pattern = "*parameters.csv", full.names = TRUE)
for (parameter.file in files) {
  
  programParameters = read.csv(parameter.file)
  
  # Initialize
  graphFileName = programParameters[1, "graph_file_name"]
  parametersTitle = ""
  for (parameterName in names(programParameters)) {
    parametersTitle <- paste(parametersTitle,(paste(parameterName, programParameters[1, parameterName], sep=": ")), sep = "\n")
  }
  
  # Read data
  edgesData = read.csv(paste(programParameters[1, "data_file"]))
  
  # Get graph
  g <- graph_from_data_frame(edgesData, directed = FALSE)
  
  # Plot graph
  pdf(file=paste(graphFileName, " site dependencies graph", ".pdf" , sep = ""), w=10, h=7)
  plot(g, edge.width=E(g)$weight/max(E(g)$weight)*2)
  title(main="Dependency graph: Which sites have dependencies? the bigger the vertex the more dependencies")
  title(sub=parametersTitle)
  dev.off()
  
}

