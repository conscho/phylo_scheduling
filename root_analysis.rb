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
tree_files =     './data/n4/random_trees/*random*'
partition_file = './data/n4/n4.model'
phylip_file =    './data/n4/n4.phy'
sample_root = true

# Initialize
root_node = ""
all_trees_operations_maximum = []
all_trees_operations_optimized = []
all_trees_operations_ratio = []
partitions = []
start_time = Time.now

logger.info("Program started at #{start_time}")
logger.info("Using parameters: Tree files: #{tree_files}; Partition file: #{partition_file}; Phylip File: #{phylip_file}")

Dir.glob(tree_files) do |file|

  # Initialize variables
  tree_operations_maximum = []
  tree_operations_optimized = []
  tree_operations_ratio = []

  # Get data
  logger.debug("Processing file: #{file}")
  tree = NewickTree.fromFile(file)
  tree = tree.read_phylip(phylip_file)
  partitions = read_partitions(partition_file)

  # Root tree
  tree_nodes = tree.nodes
  logger.info("Iterating over all #{tree_nodes.size} nodes")
  tree_nodes.each_with_index do |node, index|

    # Initialize variables
    tree_part_operations_maximum = []
    tree_part_operations_optimized = []
    tree_part_operations_ratio = []

    # Root tree
    tree = tree.reroot(node)
    logger.debug("Rooted at Node #{index}: #{node}")
    logger.debug(tree.to_s)

    # Iterate over all partitions
    partitions.each do |partition|
      result = tree.ml_operations(partition)
      tree_part_operations_maximum.push(result[0])
      tree_part_operations_optimized.push(result[1])
      tree_part_operations_ratio.push(((result[1].to_f / result[0].to_f) * 100))
    end
    tree_operations_maximum.push(tree_part_operations_maximum.mean)
    tree_operations_optimized.push(tree_part_operations_optimized.mean)
    tree_operations_ratio.push(tree_part_operations_ratio.mean)

  end

  print("Tree: #{file} with #{partitions.size} partitions and #{tree_nodes.size} nodes. Rooting tree on each node:\n")
  print("  Maximum Operations: min: #{tree_operations_maximum.min.round(2)}, max: #{tree_operations_maximum.max.round(2)}, mean: #{tree_operations_maximum.mean.round(2)}, variance: #{tree_operations_maximum.variance.round(2)}, standard deviation: #{tree_operations_maximum.standard_deviation.round(2)}\n")
  print("  Operations (without unique sites and repeats): min: #{tree_operations_optimized.min.round(2)}, max: #{tree_operations_optimized.max.round(2)}, mean: #{tree_operations_optimized.mean.round(2)}, variance: #{tree_operations_optimized.variance.round(2)}, standard deviation: #{tree_operations_optimized.standard_deviation.round(2)}\n")
  print("  Ratio: min: #{tree_operations_ratio.min.round(2)}, max: #{tree_operations_ratio.max.round(2)}, mean: #{tree_operations_ratio.mean.round(2)}, variance: #{tree_operations_ratio.variance.round(2)}, standard deviation: #{tree_operations_ratio.standard_deviation.round(2)}\n")

  all_trees_operations_maximum.push(tree_operations_maximum.mean)
  all_trees_operations_optimized.push(tree_operations_optimized.mean)
  all_trees_operations_ratio.push(tree_operations_ratio.mean)

end

logger.info("#{all_trees_operations_optimized.size} trees with #{partitions.size} partitions, rooted at node #{root_node}:")
logger.info("  Maximum Operations: min: #{all_trees_operations_maximum.min.round(2)}, max: #{all_trees_operations_maximum.max.round(2)}, mean: #{all_trees_operations_maximum.mean.round(2)}, variance: #{all_trees_operations_maximum.variance.round(2)}, standard deviation: #{all_trees_operations_maximum.standard_deviation.round(2)}")
logger.info("  Operations (without unique sites and repeats): min: #{all_trees_operations_optimized.min.round(2)}, max: #{all_trees_operations_optimized.max.round(2)}, mean: #{all_trees_operations_optimized.mean.round(2)}, variance: #{all_trees_operations_optimized.variance.round(2)}, standard deviation: #{all_trees_operations_optimized.standard_deviation.round(2)}")
logger.info("  Ratio: min: #{all_trees_operations_ratio.min.round(2)}, max: #{all_trees_operations_ratio.max.round(2)}, mean: #{all_trees_operations_ratio.mean.round(2)}, variance: #{all_trees_operations_ratio.variance.round(2)}, standard deviation: #{all_trees_operations_ratio.standard_deviation.round(2)}")

logger.info("Programm finished at #{Time.now}. Runtime: #{(Time.now - start_time).duration}")
