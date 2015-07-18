library(ggplot2)
library(grid)
library(dplyr)

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
  ggplotTheme = theme(plot.margin = unit(c(1,1,1,1), "lines"), plot.title = element_text(size = rel(0.9)))
  
  # Read and aggregate data
  rawData = read.csv(paste(programParameters[1, "data_file"]))
  aggregatedData <- summarise(group_by(rawData, batch, tree, partition, dependency), count = n())
  cumData = mutate(group_by(aggregatedData, batch, tree, partition), cumsum=cumsum(count), proportion=cumsum/sum(count))
  labelData = filter(cumData, dependency == 1)
  
  # Generate graphs
  ggplotTitle = ggtitle(paste("Barplot: Absolute count of site dependencies\n", parametersTitle))
  gp = ggplot(cumData, aes(x=dependency, y=count, fill=partition)) + geom_bar(stat="identity") + geom_text(data = labelData, aes(label = count, color=partition), hjust=0, vjust=0) + xlab("dependencies") + facet_wrap(~tree, ncol = 3) +  ggplotTheme + ggplotTitle
  ggsave(file=paste(graphFileName, " absolute site dependencies", ".pdf" , sep = ""), plot = gp, w=10, h=10)

  ggplotTitle = ggtitle(paste("Step: Cumulated count of site dependencies\n", parametersTitle))
  gp = ggplot(cumData, aes(x=dependency, y=proportion, color=partition)) + geom_step() + geom_text(data = labelData, aes(label = round(proportion, 2), color=partition), hjust=0, vjust=0) + xlab("dependencies") + facet_wrap(~tree, ncol = 3) + ylab("count") + ggplotTheme + ggplotTitle
  ggsave(file=paste(graphFileName, " cumulated site dependencies", ".pdf" , sep = ""), plot = gp, w=10, h=10)
  
}
