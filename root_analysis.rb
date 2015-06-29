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

start_time = Time.now
logger.info("Program started at #{start_time}")
logger.info("Using parameters: Tree files: #{tree_files}; Partition file: #{partition_file}; Phylip File: #{phylip_file}")

Dir.glob(tree_files) do |file|

  # Initialize variables
  operations_maximum = []
  operations_optimized = []
  operations_ratio = []

  # Get data
  logger.debug("Processing file: #{file}")
  tree = NewickTree.fromFile(file)
  tree = tree.read_phylip(phylip_file)
  partitions = read_partitions(partition_file)

  # Root tree once on each node
  tree_nodes = tree.nodes
  logger.info("Iterating over all #{tree_nodes.count} nodes")
  tree.nodes.each_with_index do |node, index|

    # Initialize variables
    partition_maximum_operations = []
    partition_operations = []
    partition_ratio = []

    # Root tree
    tree = tree.reroot(node)
    logger.debug("Rooted at Node #{index}: #{node}")
    logger.debug(tree.to_s)

    # Iterate over all partitions
    partitions.each do |partition|
      result = tree.ml_operations(partition)
      partition_maximum_operations.push(result[0])
      partition_operations.push(result[1])
      partition_ratio.push(((result[1].to_f / result[0].to_f) * 100))
    end
    operations_maximum.push(partition_maximum_operations.mean)
    operations_optimized.push(partition_operations.mean)
    operations_ratio.push(partition_ratio.mean)
  end

  print("Tree: #{file} with #{partitions.size} partitions and #{tree_nodes.count} nodes. Rooting tree on each node:\n")
  print("  Maximum Operations: min: #{operations_maximum.min.round(2)}, max: #{operations_maximum.max.round(2)}, mean: #{operations_maximum.mean.round(2)}, variance: #{operations_maximum.variance.round(2)}, standard deviation: #{operations_maximum.standard_deviation.round(2)}\n")
  print("  Operations (without unique sites and repeats): min: #{operations_optimized.min.round(2)}, max: #{operations_optimized.max.round(2)}, mean: #{operations_optimized.mean.round(2)}, variance: #{operations_optimized.variance.round(2)}, standard deviation: #{operations_optimized.standard_deviation.round(2)}\n")
  print("  Ratio: min: #{operations_ratio.min.round(2)}, max: #{operations_ratio.max.round(2)}, mean: #{operations_ratio.mean.round(2)}, variance: #{operations_ratio.variance.round(2)}, standard deviation: #{operations_ratio.standard_deviation.round(2)}\n")

end

logger.info("Programm finished at #{Time.now}. Runtime: #{(Time.now - start_time).duration}")
