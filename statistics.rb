require 'descriptive_statistics'
require './lib/helper'
require './lib/newick'
require './lib/multi_io'
require './lib/numeric'
require 'logger'

# Logger
log_file = File.open("log/root_analysis_debug.log", "a")
logger = Logger.new(MultiIO.new(STDOUT, log_file))
logger.level = Logger::DEBUG

# Program parameters
tree_files =     './data/n6/random_trees/*random*'
partition_file = './data/n6/n6.model'
phylip_file =    './data/n6/n6.phy'
sample_root = true # true if you only want to use a sample root. false if you want root on all nodes of the tree.

# Initialize
all_trees_operations_maximum = []
all_trees_operations_optimized = []
all_trees_operations_ratio = []
root_nodes = []
partitions = []
start_time = Time.now

logger.info("Program started at #{start_time}")
logger.info("Using parameters: Tree files: #{tree_files}; Partition file: #{partition_file}; Phylip File: #{phylip_file}")


Dir.glob(tree_files) do |file|

  # Get data
  logger.debug("Processing file: #{file}")
  tree = NewickTree.fromFile(file)
  tree = tree.read_phylip(phylip_file)
  partitions = read_partitions(partition_file)

  # Sample root or root once on all nodes?
  if sample_root
    root_nodes[0] = tree.findNode(tree.taxa[0])
    tree_operations_maximum, tree_operations_optimized, tree_operations_ratio =
        tree.ml_operations_for_nodes(logger, root_nodes, partitions)
  else
    root_nodes = tree.nodes
    tree_operations_maximum, tree_operations_optimized, tree_operations_ratio =
        tree.ml_operations_for_nodes(logger, root_nodes, partitions)
  end

  logger.info("Tree: #{file} with #{partitions.size} partitions rooted at #{root_nodes.size} nodes:\n")
  logger.info("  Maximum Operations: mean: #{tree_operations_maximum.round(2)}")
  logger.info("  Operations (without unique sites and repeats): mean: #{tree_operations_optimized.round(2)}")
  logger.info("  Ratio: mean: #{tree_operations_ratio.round(2)}")

  all_trees_operations_maximum.push(tree_operations_maximum)
  all_trees_operations_optimized.push(tree_operations_optimized)
  all_trees_operations_ratio.push(tree_operations_ratio)

end

logger.info("#{all_trees_operations_optimized.size} trees with #{partitions.size} partitions, rooted at #{root_nodes.size} nodes:")
logger.info("  Maximum Operations: min: #{all_trees_operations_maximum.min.round(2)}, max: #{all_trees_operations_maximum.max.round(2)}, mean: #{all_trees_operations_maximum.mean.round(2)}, variance: #{all_trees_operations_maximum.variance.round(2)}, standard deviation: #{all_trees_operations_maximum.standard_deviation.round(2)}")
logger.info("  Operations (without unique sites and repeats): min: #{all_trees_operations_optimized.min.round(2)}, max: #{all_trees_operations_optimized.max.round(2)}, mean: #{all_trees_operations_optimized.mean.round(2)}, variance: #{all_trees_operations_optimized.variance.round(2)}, standard deviation: #{all_trees_operations_optimized.standard_deviation.round(2)}")
logger.info("  Ratio: min: #{all_trees_operations_ratio.min.round(2)}, max: #{all_trees_operations_ratio.max.round(2)}, mean: #{all_trees_operations_ratio.mean.round(2)}, variance: #{all_trees_operations_ratio.variance.round(2)}, standard deviation: #{all_trees_operations_ratio.standard_deviation.round(2)}")

logger.info("Programm finished at #{Time.now}. Runtime: #{(Time.now - start_time).duration}")
