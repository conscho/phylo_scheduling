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
data_folder =    './data/500/'
tree_files =     { #pars: "parsimony_trees/*parsimonyTree*",
                   pars_ml: "parsimony_trees/*result*",
                   rand_ml: "random_trees/*result*"}
partition_file = '500.partitions'
phylip_file =    '500.phy'
sample_root = "midpoint" # Enter the amount of nodes (>= 2) that should be used to root the tree . Enter "all" for all nodes. Enter "midpoint" for midpoint root.
sample_trees = 100 # Enter the amount of trees that should be used for statistics.
height_analysis = false # For each tree get a analysis of height to ratio. Does not make sense for single root node parameter.
compare_with_likelihood = false # Create plot with ratio to likelihood distribution

# Initialize and handover to R
start_time = Time.now
graph_file_name = "graphs/#{data_folder.scan(/\w+/).join(".")} #{start_time.strftime "%Y-%m-%d %H-%M-%S"}"
partitions = read_partitions(data_folder + partition_file)
number_of_taxa, number_of_sites, phylip_data = read_phylip(data_folder + phylip_file)
R.eval("dataList = list(); library(ggplot2); library(grid); fileCounter = 1")
R.graphAxisNames = tree_files.keys.map &:to_s
R.graphFileName = graph_file_name
R.dataFolder = data_folder
R.sampleRoot = sample_root
R.sampleTrees = sample_trees
R.numberOfPartitions = partitions.size
R.numberOfTaxa = number_of_taxa
R.numberOfSites = number_of_sites

logger.info("Program started at #{start_time}")
logger.info("Using parameters: Data folder: #{data_folder}; Tree files: #{tree_files}; " \
            "Partition file: #{partition_file}; Phylip File: #{phylip_file}; " \
            "Sample root nodes: #{sample_root}; Sample trees: #{sample_trees}; " \
            "Number of taxa: #{number_of_taxa}; Number of sites: #{number_of_sites}; " \
            "Number of partitions: #{partitions.size}" )


# Get likelihood values also?
likelihoods = read_likelihood(logger, tree_files, data_folder) if compare_with_likelihood

tree_files.each do |batch_name, batch_path|

  # Initialize
  all_trees_operations_maximum = []
  all_trees_operations_optimized = []
  all_trees_operations_ratio = []
  root_nodes = []
  all_trees_likelihoods = [] if compare_with_likelihood

  Dir.glob(data_folder + batch_path).first(sample_trees).each_with_index do |file, index|

    # Get data
    logger.debug("Processing file: #{file}")
    tree = NewickTree.fromFile(file)
    tree = tree.add_dna_sequences(phylip_data)

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

    logger.info("Tree: #{file} rooted at #{root_nodes.size} node(s):")
    logger.info("  Maximum Operations: mean: #{all_trees_operations_maximum[index].round(2)}")
    logger.info("  Operations (without unique sites and repeats): mean: #{all_trees_operations_optimized[index].round(2)}")
    logger.info("  Ratio: mean: #{all_trees_operations_ratio[index].round(2)}")

    if compare_with_likelihood
      match_object = /.*\.(?<prefix>.*)\.RUN\.(?<tree_number>.*)/.match(file)
      all_trees_likelihoods[index] = likelihoods[batch_name.to_s + '-' + match_object[:prefix] + '-' + match_object[:tree_number]]
      logger.info("  Likelihood of tree: #{all_trees_likelihoods[index]}")
    end

    if height_analysis
      R.treeRatio = tree_operations_ratio
      R.height = tree_height
      R.file = file
      R.fileIndex = index
      R.key = batch_name.to_s

      R.eval <<EOF
dataFrame <- data.frame(Height=height, Ratio=treeRatio)
gp = ggplot(dataFrame, aes(x=Height, y=Ratio)) +
  geom_point(shape=19, alpha=1/10) + geom_smooth(method=lm) +
  ggtitle(paste("Comparison of height to ratio for one tree rooting over specified nodes\n",
    "Program parameters: Data folder ", dataFolder, "; Tree: " , file,
    "\n Sample root: ", sampleRoot, "; Partitions: " , numberOfPartitions, " Taxa: " , numberOfTaxa, " Sites: " , numberOfSites, sep = "")) +
  theme(plot.margin = unit(c(1,2,1,1), "lines"), plot.title = element_text(size = rel(0.9)))
ggsave(file=paste(graphFileName, " tree height analysis ", key, fileIndex, ".pdf" , sep = ""), plot = gp, w=10, h=7)
EOF
    end

  end

  logger.info(
    "#{all_trees_operations_optimized.size} trees, taken from #{data_folder + batch_path} ,"\
    "rooted at #{root_nodes.size} nodes:"
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
  if compare_with_likelihood
    R.likelihoods = all_trees_likelihoods
    R.key = batch_name.to_s
    R.eval <<EOF
dataFrame <- data.frame(Likelihood=likelihoods, Ratio=ratio)
gp = ggplot(dataFrame, aes(x=Likelihood, y=Ratio)) +
  geom_point(shape=19, alpha=1/10) + geom_smooth(method=lm) +
  ggtitle(paste("Comparison of likelihood to ratio for one type of tree\n",
    "Program parameters: Data folder ", dataFolder, "; Batch type: ", key, "; Sample root: ", sampleRoot,
    "\nPartitions: " , numberOfPartitions, "; Taxa: " , numberOfTaxa, "; Sites: " , numberOfSites, sep = "")) +
  theme(plot.margin = unit(c(1,2,1,1), "lines"), plot.title = element_text(size = rel(0.9)))
ggsave(file=paste(graphFileName, " likelihood analysis ", key, ".pdf" , sep = ""), plot = gp, w=10, h=7)
EOF
  end

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
mtext(paste("Program parameters: Data folder ", dataFolder, "; Sample root: ", sampleRoot,
            "; Sample trees: " , sampleTrees, "\nPartitions: " , numberOfPartitions,
            "; Taxa: " , numberOfTaxa, "; Sites: " , numberOfSites, "; Runtime: ", runtime, sep = ""), side=1, line=5)
text(array(1:length(dataList)), sapply(dataList,median) + 0.05, sapply(dataList,median))
dev.off()
EOF

logger.info("Graph written to #{graph_file_name}")


# end