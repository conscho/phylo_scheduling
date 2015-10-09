library(ggplot2)
library(grid)
library(dplyr)
library(plyr)
library(gridExtra)



ggplotTheme = theme(plot.margin = unit(c(1,1,1,1), "lines"), plot.title = element_text(size = rel(0.9)))
ggplotRotateLabel = theme(axis.text.x = element_text(angle = 90, hjust = 1))


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
  rawData <- rename(rawData, c("op_optimized"="operations_sites"))
  
  rawData2 = read.csv(paste(programParameters[1, "data_file"]))
  rawData2$type <- "sites"
  rawData2 <- rename(rawData2, c("op_optimized"="operations_sites"))
  rawData2$operations_sites <- rawData2$sites

  combData = rbind(rawData, rawData2)
  
  # Calculate operations and savings for largest bin
  sumData = aggregate(rawData[c("operations_sites", "op_maximum")], by=rawData[c("bin", "description", "type")], FUN=sum)
  sumData$savings <- round((sumData$op_maximum - sumData$operations_sites)/sumData$op_maximum*100, 2)
  sumData = sumData %>%
    group_by(description) %>%
    slice(which.max(operations_sites))
  
  # Get number of split partitions
  splitData = rawData %>% 
    group_by(description, partition) %>% 
    filter(n()>1) %>%
    dplyr::summarize(count=n()-1) %>%
    group_by(description) %>%
    dplyr::summarize(splits = sum(count))
  sumData = inner_join(sumData, splitData, by = "description")
  
  
  # Generate graphs
  ggplotTitle = ggtitle(paste("Barchart scheduling: Partition distribution to bins for various heuristics\nRed horizontal line = lower bound\n", parametersTitle))
  gp = ggplot(combData, aes(x=bin, ymax=operations_sites)) + 
    scale_x_discrete(limit = 0:max(combData$bin)) + 
    geom_blank(aes(y=operations_sites*1.1), position = "stack") + ylab("") + ## Dirty hack to increase upper boundary of y-axis 
    geom_rect(data = subset(sumData, operations_sites == min(sumData$operations_sites)), aes(xmin = -Inf, ymin = -Inf, xmax = +Inf, ymax = Inf), fill = "green", alpha = 30/100) + 
    geom_bar(aes(x=bin, y=operations_sites, fill=partition), stat="identity", colour="black") + 
    geom_text(aes(label=operations_sites, bin, operations_sites), position="stack", vjust = +1, size=2) + 
    geom_text(aes(0, operations_sites, label=paste("largest bin:\n", "operations: ", operations_sites, "\n", "savings: ", savings, "%", "\n", "splits: ", splits, sep=""), group=NULL), data=sumData, vjust=-0.3, hjust=0.1/max(combData$bin), color = "red", size=3) + 
    geom_line(aes(x=bin, y=optimum), color="red", data=rawData) + 
    facet_grid(type~description, scales = "free_y") + 
    ggplotTheme + ggplotTitle + ggplotRotateLabel
  ggsave(file=paste(graphFileName, " scheduling", ".pdf" , sep = ""), plot = gp, w=90, h=15, limitsize=FALSE)
  
}





