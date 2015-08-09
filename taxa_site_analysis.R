library(ggplot2)
library(grid)
library(dplyr)
library(gridExtra)


ggplotTheme = theme(plot.margin = unit(c(1,1,1,1), "lines"), plot.title = element_text(size = rel(0.9)))
ggplotRotateLabel = theme(axis.text.x = element_text(angle = 90, hjust = 1))


files <- list.files("output_taxa_site_analysis", pattern = "*parameters.csv", full.names = TRUE)
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
  gp = ggplot(rawData, aes(x=number_of_sites, y=number_of_taxa)) + geom_tile(aes(fill=ratio_of_savings)) + facet_wrap(~partition) + ggplotTheme + ggplotTitle + scale_fill_gradient(low="white", high="red")
  ggsave(file=paste(graphFileName, " taxa site analysis", ".pdf" , sep = ""), plot = gp, w=10, h=7)
  
}





