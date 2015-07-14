library(ggplot2)
library(grid)

programParameters = read.csv("output/2015-07-14 00-07-32 parameters.csv")

# Initialize
graphFileName = programParameters[1, "graph_file_name"]
parametersTitle = paste("Data folder:", programParameters[1, "data_folder"], "Number of partitions:", programParameters[1, "number_of_partitions"],
						"Number of taxa:", programParameters[1, "number_of_taxa"], "Number of sites:", programParameters[1, "number_of_sites"],
						"\nSample root:", programParameters[1, "sample_root"], "Sample trees:", programParameters[1, "sample_trees"],
						"\nCompare with likelihood:", programParameters[1, "compare_with_likelihood"],
						"Height analysis:", programParameters[1, "height_analysis"], "\nProgram runtime:", programParameters[1, "program_runtime"], sep = " ")
ggplotTheme = theme(plot.margin = unit(c(1,1,1,1), "lines"), plot.title = element_text(size = rel(0.9)))

# Read Data and aggregate
rubyData = read.csv(paste(programParameters[1, "data_file"]))
aggregatedData <- aggregate(rubyData[c("operations_maximum","operations_optimized")], by=rubyData[c("tree","batch","likelihood","root_node","height")], FUN=mean)
aggregatedData$operations_ratio <- (aggregatedData$operations_optimized / aggregatedData$operations_maximum)


# Generate graphs
ggplotTitle = ggtitle(paste("Boxplot: Ratio per batch\n", parametersTitle))
gp = ggplot(aggregatedData, aes(batch, operations_ratio)) + geom_boxplot() + ggplotTheme + ggplotTitle
ggsave(file=paste(graphFileName, " ratio per batch", ".pdf" , sep = ""), plot = gp, w=10, h=7)

ggplotTitle = ggtitle(paste("Scatterplot: Likelihood to Ratio\n", parametersTitle))
gp = ggplot(aggregatedData, aes(likelihood, operations_ratio, color=batch)) + geom_point(shape=19, alpha=1/4) + geom_smooth(method=lm) + ggplotTheme + ggplotTitle
ggsave(file=paste(graphFileName, " likelihood to ratio", ".pdf" , sep = ""), plot = gp, w=10, h=7)

ggplotTitle = ggtitle(paste("Boxplot: Comparison of partitions for each tree\n", parametersTitle))
gp = ggplot(rubyData, aes(partition, operations_ratio, color=batch)) + geom_boxplot() + ggplotTheme + ggplotTitle
ggsave(file=paste(graphFileName, " ratio of partitions per batch", ".pdf" , sep = ""), plot = gp, w=10, h=7)

ggplotTitle = ggtitle(paste("Scatterplot: height to ratio\n", parametersTitle))
gp = ggplot(aggregatedData, aes(height, operations_ratio, color=batch)) + geom_point(shape=19, alpha=1/4) + ggplotTheme + ggplotTitle
ggsave(file=paste(graphFileName, " height to ratio", ".pdf" , sep = ""), plot = gp, w=10, h=7)
