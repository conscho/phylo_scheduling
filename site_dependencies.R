library(ggplot2)
library(grid)
library(dplyr)

ggplotTheme = theme(plot.margin = unit(c(1,1,1,1), "lines"), plot.title = element_text(size = rel(0.9)))
ggplotRotateLabel = theme(axis.text.x = element_text(angle = 90, hjust = 1))


files <- list.files("output_site_dependencies", pattern = "*parameters.csv", full.names = TRUE)
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
  ggplotTitle = ggtitle(paste("Line: How many dependencies per site?\n", parametersTitle))
  gp = ggplot(rawData, aes(x=site, y=count, color=partition)) + ggplotRotateLabel + geom_line() + facet_wrap(~tree, ncol = 1) + ggplotTheme + ggplotTitle
  ggsave(file=paste(graphFileName, " site dependencies", ".pdf" , sep = ""), plot = gp, w=10, h=10)

  ggplotTitle = ggtitle(paste("Scatterplot: Distribution of site dependencies for all trees\n", parametersTitle))
  gp = ggplot(rawData, aes(x=reorder(site,count), y=count, color=partition)) + ggplotRotateLabel + geom_point(shape=19, alpha=1/4) + scale_x_discrete(breaks=NULL, name="sorted sites") + facet_wrap(~tree, ncol = 1) + ggplotTheme + ggplotTitle
  ggsave(file=paste(graphFileName, " site dependency distribution for all trees", ".pdf" , sep = ""), plot = gp, w=10, h=10)
  
  ggplotTitle = ggtitle(paste("Scatterplot: Distribution of site dependencies for one tree\n", parametersTitle))
  gp = ggplot(filter(rawData, grepl('RAxML_parsimonyTree', tree)), aes(x=reorder(site,count), y=count)) + ggplotRotateLabel + geom_point(shape=19, alpha=1/4) + scale_x_discrete(breaks=NULL, name="sorted sites") + facet_wrap(~partition, ncol = 3) + ggplotTheme + ggplotTitle
  ggsave(file=paste(graphFileName, " site dependency distribution for one tree", ".pdf" , sep = ""), plot = gp, w=10, h=10)
}
