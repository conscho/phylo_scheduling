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

  # Calculate operations and savings for largest bin
  sumData = aggregate(rawData[c("operations_sites", "op_maximum")], by=rawData[c("bin", "description", "type")], FUN=sum)
  sumData$savings <- round((sumData$op_maximum - sumData$operations_sites)/sumData$op_maximum*100, 2)
  sumData = sumData %>%
    group_by(description) %>%
    slice(which.max(operations_sites))
  
  rawData2 = read.csv(paste(programParameters[1, "data_file"]))
  rawData2$type <- "sites"
  rawData2 <- rename(rawData2, c("op_optimized"="operations_sites"))
  rawData2$operations_sites <- rawData2$sites
  combData = rbind(rawData, rawData2)
  
  # Generate graphs
  ggplotTitle = ggtitle(paste("Barchart: Partition distribution to bins\n", parametersTitle))
  gp = ggplot(combData, aes(x=bin)) + scale_x_discrete() + geom_bar(aes(x=bin, y=operations_sites, fill=partition), stat="identity", colour="black") + geom_text(aes(label=operations_sites, bin, operations_sites), position="stack", vjust = +1, size=3) + geom_text(aes(0, operations_sites, label=paste("operations: ", operations_sites, "\n", "savings: ", savings, "%", sep=""), group=NULL), data=sumData, vjust=+0.5, hjust=0, color = "red", size=4) + facet_grid(type~description, scales = "free_y") + ggplotTheme + ggplotTitle + ggplotRotateLabel
  ggsave(file=paste(graphFileName, " scheduling", ".pdf" , sep = ""), plot = gp, w=14, h=10)
  
}





