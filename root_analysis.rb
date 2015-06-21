require 'descriptive_statistics'
require './lib/newick'
require './lib/helper'


Dir.glob('./data/medium/parsimony_trees/*parsimonyTree*') do |file|
  # Initialize variables
  maximum_operations = []
  operations = []
  ratio = []

  # Get data
  print("Processing file: #{file}\n")
  tree = NewickTree.fromFile(file)
  partitions = read_partitions_from_file("./data/medium/n6.model")
  partitions_length = partitions.count

  # Root tree once on each node
  tree_nodes = tree.nodes
  print("Iterating over all #{tree_nodes.count} nodes\n")
  tree.nodes.each_with_index do |node, index|
    # Initialize variables
    partition_maximum_operations = []
    partition_operations = []
    partition_ratio = []

    # Root tree
    root = node
    print("Rooted at Node #{index}: #{root}\n")
    tree = tree.reroot(node)
    print(tree.to_s + "\n")

    # Iterate over all partitions
    partitions.each do |partition|
      tree_partition = tree.read_phylip("./data/medium/n6.phy", partition)

      result = tree_partition.ml_operations
      partition_maximum_operations.push(result[0])
      partition_operations.push(result[1])
      partition_ratio.push(((result[1].to_f / result[0].to_f) * 100))
    end
    maximum_operations.push(partition_maximum_operations.mean)
    operations.push(partition_operations.mean)
    ratio.push(partition_ratio.mean)
  end

  print("Tree: #{file} with #{partitions_length} partitions and #{tree_nodes.count} nodes. Rooting tree on each node:\n")
  print("  Maximum Operations: min: #{maximum_operations.min.round(2)}, max: #{maximum_operations.max.round(2)}, mean: #{maximum_operations.mean.round(2)}, variance: #{maximum_operations.variance.round(2)}, standard deviation: #{maximum_operations.standard_deviation.round(2)}\n")
  print("  Operations (without unique sites and repeats): min: #{operations.min.round(2)}, max: #{operations.max.round(2)}, mean: #{operations.mean.round(2)}, variance: #{operations.variance.round(2)}, standard deviation: #{operations.standard_deviation.round(2)}\n")
  print("  Ratio: min: #{ratio.min.round(2)}, max: #{ratio.max.round(2)}, mean: #{ratio.mean.round(2)}, variance: #{ratio.variance.round(2)}, standard deviation: #{ratio.standard_deviation.round(2)}\n")

end


