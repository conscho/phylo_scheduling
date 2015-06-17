require 'descriptive_statistics'
require './lib/newick'
require './lib/helper'


=begin
# Get data
tree = NewickTree.fromFile("./data/medium/medium.tree")
partitions = read_partitions_from_file("./data/medium/medium.model")

# Root tree
root = "241"
print("Rooted at #{root}: ")
tree = tree.reroot(tree.findNode(root))
print(tree.to_s + "\n")

# Results for each partition
partitions.each do |partition|
  print("Results for partition #{partition}:\n")
  tree_partition = tree.read_phylip("./data/medium/medium.phy", partition)
  operations = tree_partition.ml_operations
  print("  Maximum Operations: " + operations[0].to_s + "\n")
  print("  Operations (without unique sites and repeats): " + operations[1].to_s + "\n")
  print("  Ratio: " + ((operations[1].to_f / operations[0].to_f) * 100).round(2).to_s + "% \n")
end
=end



maximum_operations = []
operations = []
ratio = []
partitions_length = 0

Dir.glob('./data/medium/random_trees/*') do |file|

  # Get data
  print("Processing file: #{file}\n")
  tree = NewickTree.fromFile(file)
  partitions = read_partitions_from_file("./data/medium/medium.model")
  partitions_length = partitions.count

  # Root tree
  root = "241"
  print("Rooted at #{root}: ")
  tree = tree.reroot(tree.findNode(root))
  print(tree.to_s + "\n")


  partitions.each do |partition|
    tree_partition = tree.read_phylip("./data/medium/medium.phy", partition)

    result = tree_partition.ml_operations
    maximum_operations.push(result[0])
    operations.push(result[1])
    ratio.push(((result[1].to_f / result[0].to_f) * 100).round(2))
  end
end

print("#{maximum_operations.count / partitions_length} rooted trees with #{partitions_length} partitions:\n")
print("  Maximum Operations: mean: #{maximum_operations.mean}, variance: #{maximum_operations.variance}, standard deviation: #{maximum_operations.standard_deviation.round(2)}\n")
print("  Operations (without unique sites and repeats): mean: #{operations.mean}, variance: #{operations.variance}, standard deviation: #{operations.standard_deviation.round(2)}\n")
print("  Ratio: mean: #{ratio.mean}, variance: #{ratio.variance}, standard deviation: #{ratio.standard_deviation.round(2)}\n")

