require 'descriptive_statistics'
require './lib/helper'
require './lib/newick'
require './lib/multi_io'
require 'logger'

# Logger
log_file = File.open("log/debug.log", "a")
logger = Logger.new(MultiIO.new(STDOUT, log_file))

# Program parameters
tree_files =     './data/n6/random_trees/*random*'
partition_file = './data/n6/n6.model'
phylip_file =    './data/n6/n6.phy'

# Initialize
root_node = ""
operations_maximum = []   # without any optimization
operations_optimized = [] # with optimization
operations_ratio = []
partitions = []
start_time = Time.now

logger.info("Program started at #{start_time}")
logger.info("Using parameters: Tree files: #{tree_files}; Partition file: #{partition_file}; Phylip File: #{phylip_file}")

Dir.glob(tree_files) do |file|

  # Get data
  logger.debug("Processing file: #{file}")
  tree = NewickTree.fromFile(file)
  partitions = read_partitions(partition_file)

  # Root tree on first leaf alphabetically sorted
  root_node = tree.taxa[0]
  logger.debug("Rooted at #{root_node}: ")
  tree = tree.reroot(tree.findNode(root_node))
  logger.debug(tree.to_s)

  partitions.each do |partition|
    tree_partition = tree.read_phylip(phylip_file, partition)

    result = tree_partition.ml_operations
    operations_maximum.push(result[0])
    operations_optimized.push(result[1])
    operations_ratio.push(((result[1].to_f / result[0].to_f) * 100))
  end
end

logger.debug("#{operations_maximum.size/ partitions.size} trees with #{partitions.size} partitions, rooted at node #{root_node}:")
logger.debug("  Maximum Operations: min: #{operations_maximum.min.round(2)}, max: #{operations_maximum.max.round(2)}, mean: #{operations_maximum.mean.round(2)}, variance: #{operations_maximum.variance.round(2)}, standard deviation: #{operations_maximum.standard_deviation.round(2)}")
logger.debug("  Operations (without unique sites and repeats): min: #{operations_optimized.min.round(2)}, max: #{operations_optimized.max.round(2)}, mean: #{operations_optimized.mean.round(2)}, variance: #{operations_optimized.variance.round(2)}, standard deviation: #{operations_optimized.standard_deviation.round(2)}")
logger.debug("  Ratio: min: #{operations_ratio.min.round(2)}, max: #{operations_ratio.max.round(2)}, mean: #{operations_ratio.mean.round(2)}, variance: #{operations_ratio.variance.round(2)}, standard deviation: #{operations_ratio.standard_deviation.round(2)}")



# # Get data
# tree = NewickTree.fromFile("./data/medium/medium.tree")
# partitions = read_partitions_from_file("./data/medium/medium.model")
#
# # Root tree
# root = "241"
# print("Rooted at #{root}: ")
# tree = tree.reroot(tree.findNode(root))
# print(tree.to_s + "\n")
#
# # Results for each partition
# partitions.each do |partition|
#   print("Results for partition #{partition}:\n")
#   tree_partition = tree.read_phylip("./data/medium/medium.phy", partition)
#   operations = tree_partition.ml_operations
#   print("  Maximum Operations: " + operations[0].to_s + "\n")
#   print("  Operations (without unique sites and repeats): " + operations[1].to_s + "\n")
#   print("  Ratio: " + ((operations[1].to_f / operations[0].to_f) * 100).round(2).to_s + "% \n")
# end