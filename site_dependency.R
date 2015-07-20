library(ggplot2)
library(grid)
library(dplyr)

ggplotTheme = theme(plot.margin = unit(c(1,1,1,1), "lines"), plot.title = element_text(size = rel(0.9)))
ggplotRotateLabel = theme(axis.text.x = element_text(angle = 90, hjust = 1))


files <- list.files("output_site_dependency", pattern = "*parameters.csv", full.names = TRUE)
for (parameter.file in files) {
  
  programParameters = read.csv(parameter.file)
  
  # Initialize
  graphFileName = programParameters[1, "graph_file_name"]
  parametersTitle = paste("Data folder:", programParameters[1, "data_folder"], "Number of partitions:", programParameters[1, "number_of_partitions"],
                          "Number of taxa:", programParameters[1, "number_of_taxa"], "Number of sites:", programParameters[1, "number_of_sites"],
                          "\nSample root:", programParameters[1, "sample_root"], "Sample trees:", programParameters[1, "sample_trees"],
                          "\nProgram runtime:", programParameters[1, "program_runtime"],
                          "Number of processes:", programParameters[1, "number_of_processes"], sep = " ")
  
  
  # Read and aggregate data
  rawData = read.csv(paste(programParameters[1, "data_file"]))
#  aggregatedData <- summarise(group_by(rawData, batch, tree, partition, count), number_of_sites = n())
#  mutData = mutate(group_by(rawData, batch, tree, partition, count), name=as.character(site))
#   labelData = filter(rawData, count == 1)
  
  # Generate graphs
  ggplotTitle = ggtitle(paste("Line: How many dependencies per site?\n", parametersTitle))
  gp = ggplot(rawData, aes(x=site, y=count, color=partition)) + ggplotRotateLabel + geom_line() + facet_wrap(~tree, ncol = 1) + ggplotTheme + ggplotTitle
  ggsave(file=paste(graphFileName, " site dependencies", ".pdf" , sep = ""), plot = gp, w=10, h=10)

  ggplotTitle = ggtitle(paste("Scatterplot: Distribution of site dependencies\n", parametersTitle))
  gp = ggplot(rawData, aes(x=reorder(site,count), y=count, color=partition)) + ggplotRotateLabel + geom_point(shape=19, alpha=1/4) + scale_x_discrete(breaks=NULL, name="sorted sites") + facet_wrap(~tree, ncol = 1) + ggplotTheme + ggplotTitle
  ggsave(file=paste(graphFileName, " site dependency distribution1", ".pdf" , sep = ""), plot = gp, w=10, h=10)
  
  ggplotTitle = ggtitle(paste("Scatterplot: Distribution of site dependencies for one tree\n", parametersTitle))
  gp = ggplot(filter(rawData, grepl('RAxML_parsimonyTree', tree)), aes(x=reorder(site,count), y=count)) + + ggplotRotateLabel + geom_point(shape=19, alpha=1/4) + scale_x_discrete(breaks=NULL, name="sorted sites") + facet_wrap(~partition, ncol = 3) + ggplotTheme + ggplotTitle
  ggsave(file=paste(graphFileName, " site dependency distribution2", ".pdf" , sep = ""), plot = gp, w=10, h=10)
}
