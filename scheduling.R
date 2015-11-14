library(ggplot2)
library(grid)
library(dplyr)


ggplotTheme = theme(plot.margin = unit(c(1,1,1,1), "lines"), plot.title = element_text(size = rel(0.9)))
ggplotRotateLabel = theme(axis.text.x = element_text(angle = 90, hjust = 1, vjust = 0.5))

# Init for total comparison of heuristics
totalComparison = data_frame()


files <- list.files("output_scheduling", pattern = "*parameters.csv", full.names = TRUE)
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
  rawData <- dplyr::rename(rawData, graph_points = op_optimized)
  rawData = dplyr::select(rawData, -sites)
  
  rawData2 = read.csv(paste(programParameters[1, "data_file"]))
  rawData2$type <- "sites"
  rawData2 <- dplyr::rename(rawData2, graph_points = op_optimized)
  rawData2$graph_points <- rawData2$sites
  rawData2 = dplyr::select(rawData2, -lower_bound, -sites)
  
  combData = full_join(rawData, rawData2)
  
  
  # Calculate summary data
  sumData = aggregate(rawData[c("graph_points", "op_maximum")], by=rawData[c("bin", "description", "type", "lower_bound")], FUN=sum)
  sumData <- dplyr::rename(sumData, op_optimized = graph_points)
  sumData$savings <- round((sumData$op_maximum - sumData$op_optimized)/sumData$op_maximum*100, 2)
  sumData = sumData %>%
    group_by(description) %>%
    slice(which.max(op_optimized))
  # Add relative difference between lower_bound and largest bin
  sumData$op_optimized_rel <- round(sumData$op_optimized / sumData$lower_bound, 4)
  sumData$lower_bound_rel <- 1
  # Get number of split partitions
  splitData = rawData %>% 
    group_by(description, partition) %>% 
    dplyr::summarize(count=n()-1) %>%
    ungroup %>%
    group_by(description) %>%
    dplyr::summarize(splits = sum(count))
  sumData = full_join(sumData, splitData)
  
  # Create overall summary
  if(programParameters[1, "groundtruth"] == "false") {
    # Add sumData with own column graphFileName
    sumData$fileName <- graphFileName
    totalComparison <- rbind(totalComparison, sumData)
  }
  
  
  # Generate graph
  ggplotTitle = ggtitle(paste("Barchart scheduling: Partition distribution to bins for various heuristics\nRed horizontal line = lower bound\n", parametersTitle))
  gp = ggplot(combData, aes(x=bin, ymax=0)) + 
    scale_x_discrete(limit = 0:max(combData$bin)) + ylab("") + 
    geom_blank(aes(y=graph_points*1.1), position = "stack") + ## Dirty hack to increase upper boundary of y-axis 
    geom_rect(data = subset(sumData, op_optimized == min(sumData$op_optimized)), aes(xmin = -Inf, ymin = -Inf, xmax = +Inf, ymax = Inf), fill = "green", alpha = 30/100) + 
    geom_bar(aes(x=bin, y=graph_points, fill=partition), stat="identity", colour="black") + 
    geom_text(aes(label=graph_points, bin, graph_points), position="stack", vjust = +1, size=2) + 
    geom_text(aes(0, op_optimized, label=paste("largest bin:\n", "operations: ", op_optimized, "\n", "savings: ", savings, "%", "\n", "splits: ", splits, sep=""), group=NULL), data=sumData, vjust=-0.3, hjust=0.1/max(combData$bin), color = "red", size=3) + 
    geom_line(aes(x=bin, y=lower_bound), color="red", data=rawData) +
    facet_grid(type~description, scales = "free_y") + 
    ggplotTheme + ggplotTitle
  ggsave(file=paste(graphFileName, " scheduling", ".pdf" , sep = ""), plot = gp, w=90, h=15, limitsize=FALSE)
  
  
  
  # Create dummy facetting for graph
  sumDataCopy <- sumData
  sumDataCopy$type <- "splits"
  sumDataCopy$graph_points <- sumDataCopy$splits
  sumDataCopy$lower_bound_rel <- NULL
  sumData$graph_points <- sumData$op_optimized_rel
  sumData = full_join(sumData, sumDataCopy)
  
  # Generate graph
  ggplotTitle = ggtitle(paste("Linechart scheduling: Relative difference of largest bin to lower bound", parametersTitle))
  gp = ggplot(sumData, aes(x=reorder(description, op_optimized_rel), y=graph_points, group=1)) + 
    xlab("heuristics") + ylab("relative difference to lower_bound") +
    geom_bar(stat = "identity") + 
    geom_text(aes(label = graph_points), vjust = +1.5, size = 3, color="white") +
    geom_line(aes(description, lower_bound_rel), color="red") +
    facet_wrap(~type, scales = "free_y", ncol=1) + 
    ggplotTheme + ggplotTitle + ggplotRotateLabel
  ggsave(file=paste(graphFileName, " scheduling2", ".pdf" , sep = ""), plot = gp, w=25, h=10)
  
  
}

# Only if there are results
if(NROW(totalComparison) > 0) {
  
  # Get mean squared error and mean splits
  totalComparison$comparison <- (totalComparison$op_optimized_rel - totalComparison$lower_bound_rel) * 100
  # Dummy facetting for graph
  totalData1 = totalComparison %>%
    group_by(description) %>%
    dplyr::summarise(graph_points = round(mean(comparison), 4), comparison = round(mean(comparison), 4))
  totalData1$type <- "comparison"
  totalData2 = totalComparison %>%
    group_by(description) %>%
    dplyr::summarise(graph_points = round(mean(splits), 2), comparison = round(mean(comparison), 4))
  totalData2$type <- "splits"
  totalData = full_join(totalData1, totalData2)
  totalData$type <- factor(totalData$type, levels = c("comparison", "splits"))
  
  # Generate graph
  ggplotTitle = ggtitle(paste("Linechart: Comparison of #operations of each heuristics to the lower bound over all datasets\n", 
                              "Total datasets: ", length(unique(totalComparison$fileName))))
  gp = ggplot(totalData, aes(x=reorder(description, comparison), y=graph_points, group=1)) + 
    xlab("heuristics") + ylab("absolute number of splits || percentage in comparison to lower bound") +
    geom_bar(stat = "identity") + 
    geom_text(aes(label = graph_points), vjust = +1, hjust=-.2, size = 3, angle=90) +
    facet_wrap(~type, ncol = 1, scales = "free_y") +
    ggplotTheme + ggplotTitle + ggplotRotateLabel
  ggsave(file="graphs/comparison scheduling.pdf", plot = gp, w=20, h=8)
  
}