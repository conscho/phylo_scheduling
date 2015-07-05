require './lib/helper'
require './lib/newick'
require './lib/multi_io'
require './lib/numeric'
require 'stackprof'
require 'logger'
require 'descriptive_statistics'
require 'rinruby'

# StackProf.run(mode: :cpu, out: 'stackprof-output.dump') do

# Logger
log_file = File.open("log/debug.log", "a")
logger = Logger.new(MultiIO.new(STDOUT, log_file))
logger.level = Logger::INFO

# Program parameters
data_folder =    './data/n6/'
tree_files =     { pars: "parsimony_trees/*parsimonyTree*",
                   pars_ml: "parsimony_trees/*result*",
                   rand_ml: "random_trees/*result*"}
partition_file = 'n6.model'
phylip_file =    'n6.phy'
sample_root = "midpoint" # Enter the amount of nodes (>= 2) that should be used to root the tree . Enter "all" for all nodes. Enter "midpoint" for midpoint root.
sample_trees = 1 # Enter the amount of trees that should be used for statistics.
height_analysis = false # For each tree get a analysis of dependency vs ratio. Does not make sense for single root node parameter.

# Initialize and handover to R
start_time = Time.now
graph_file_name = "graphs/#{start_time}"
R.eval("dataList = list(); library(ggplot2); library(grid); fileCounter = 1")
R.graphAxisNames = tree_files.keys.map &:to_s
R.graphFileName = graph_file_name
R.dataFolder = data_folder
R.sampleRoot = sample_root
R.sampleTrees = sample_trees

logger.info("Program started at #{start_time}")
logger.info("Using parameters: Data folder: #{data_folder}; Tree files: #{tree_files}; " \
            "Partition file: #{partition_file}; Phylip File: #{phylip_file} " \
            "Sample root nodes: #{sample_root}; Sample trees: #{sample_trees}")


tree_files.each do |key, batch|

  # Initialize
  all_trees_operations_maximum = []
  all_trees_operations_optimized = []
  all_trees_operations_ratio = []
  root_nodes = []
  partitions = []

  Dir.glob(data_folder + batch).first(sample_trees).each_with_index do |file, index|

    # Get data
    logger.debug("Processing file: #{file}")
    tree = NewickTree.fromFile(file)
    tree = tree.read_phylip(data_folder + phylip_file)
    partitions = read_partitions(data_folder + partition_file)

    # Sample root, midpoint root or root once on all nodes?
    if sample_root == "all"
      root_nodes = tree.nodes
    elsif sample_root == "midpoint"
      tree = tree.set_edge_length.midpoint_root
      root_nodes[0] = tree.root
    else
      root_nodes = tree.nodes.first(sample_root)
    end
    tree_operations_maximum, tree_operations_optimized, tree_operations_ratio, tree_height =
        tree.ml_operations_for_nodes(logger, root_nodes, partitions, height_analysis)

    all_trees_operations_maximum[index] = tree_operations_maximum.mean
    all_trees_operations_optimized[index] = tree_operations_optimized.mean
    all_trees_operations_ratio[index] = tree_operations_ratio.mean

    logger.info("Tree: #{file} with #{partitions.size} partitions rooted at #{root_nodes.size} node(s):")
    logger.info("  Maximum Operations: mean: #{all_trees_operations_maximum[index].round(2)}")
    logger.info("  Operations (without unique sites and repeats): mean: #{all_trees_operations_optimized[index].round(2)}")
    logger.info("  Ratio: mean: #{all_trees_operations_ratio[index].round(2)}")

    if height_analysis
      R.treeRatio = tree_operations_ratio
      R.height = tree_height
      R.file = file
      R.fileIndex = index
      R.key = key.to_s

      R.eval <<EOF
dataFrame <- data.frame(Ratio=treeRatio, Height=height)
gp = ggplot(dataFrame, aes(x=Ratio, y=Height)) +
  geom_point(shape=19, alpha=1/10) + geom_smooth(method=lm) +
  ggtitle(paste("Comparison of height to ratio for one tree rooting over all nodes\n",
    "Program parameters: Data folder ", dataFolder, "; Tree: " , file, "; Sample root: ", sampleRoot, sep = "")) +
  theme(plot.margin = unit(c(2,1,1,1), "lines"), plot.title = element_text(size = rel(0.9)))
ggsave(file=paste(graphFileName, " Tree height analysis ", key, fileIndex, ".pdf" , sep = ""), plot = gp, w=10, h=7)
EOF
    end

  end

  logger.info(
    "#{all_trees_operations_optimized.size} trees, taken from #{data_folder + batch} "\
    "with #{partitions.size} partitions, rooted at #{root_nodes.size} nodes:"
  )
  logger.info(
    "  Maximum Operations: min: #{all_trees_operations_maximum.min.round(2)}, "\
    "max: #{all_trees_operations_maximum.max.round(2)}, mean: #{all_trees_operations_maximum.mean.round(2)}, "\
    "variance: #{all_trees_operations_maximum.variance.round(2)}, "\
    "standard deviation: #{all_trees_operations_maximum.standard_deviation.round(2)}"
  )
  logger.info(
    "  Operations (without unique sites and repeats): min: #{all_trees_operations_optimized.min.round(2)}, "\
    "max: #{all_trees_operations_optimized.max.round(2)}, mean: #{all_trees_operations_optimized.mean.round(2)}, "\
    "variance: #{all_trees_operations_optimized.variance.round(2)}, "\
    "standard deviation: #{all_trees_operations_optimized.standard_deviation.round(2)}"
  )
  logger.info(
    "  Ratio: min: #{all_trees_operations_ratio.min.round(2)}, max: #{all_trees_operations_ratio.max.round(2)}, "\
    "mean: #{all_trees_operations_ratio.mean.round(2)}, variance: #{all_trees_operations_ratio.variance.round(2)}, "\
    "standard deviation: #{all_trees_operations_ratio.standard_deviation.round(2)}"
  )

  # Handover to R
  R.ratio = all_trees_operations_ratio
  R.eval("dataList = c(dataList, list(ratio))")

end

program_runtime = (Time.now - start_time).duration
logger.info("Programm finished at #{Time.now}. Runtime: #{program_runtime}")

R.runtime = program_runtime
R.eval <<EOF
names(dataList) <- graphAxisNames
pdf(file=paste(graphFileName, ".pdf", sep=""), width=10, height=7)
boxplot(dataList, main=toupper("Comparison of trees from one dataset"),
        xlab="Type of trees for the dataset", ylab="Ratio of computational savings",
        par(mar = c(8, 5, 3, 2) + 0.1), yaxt="n")
axis(2, las=2)
mtext(paste("Program parameters: Data folder ", dataFolder, "; Sample root: ", sampleRoot, "; Sample trees: " , sampleTrees, "; Runtime: ", runtime, sep = ""), side=1, line=5)
text(array(1:length(dataList)), sapply(dataList,median) + 0.05, sapply(dataList,median))
dev.off()
EOF

logger.info("Graph written to #{graph_file_name}")


# end