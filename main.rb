require 'descriptive_statistics'
require './lib/newick'


# Test code
tree = NewickTree.fromFile("./data/test/test.tree")
partitions = [[1, 4]] # manual partitions

print("Unrooted - doesn't make sense...?\n")
tree = tree.read_phylip("./data/test/test.phy", partitions[0])
print(tree.to_s + "\n")

calculations = tree.ml_calculations
print((calculations).to_s + "\n")

root = "Seq5"
print("Rooted at #{root}\n")
tree = tree.reroot(tree.findNode(root))
print(tree.to_s + "\n")

calculations = tree.ml_calculations
print("[Unique Operations, Operations]: " + (calculations).to_s + "\n")



=begin

unroot_calc = [] # Unrooted calculations without subtree repeat optimization
unroot_calc_optim = []  # Unrooted calculations with subtree repeat optimization
midpoint_calc = []
midpoint_calc_optim = []

Dir.glob('./data/medium/*.tree') do |file|
  print("Processing file: #{file}\n")
  tree = NewickTree.fromFile(file)
  tree = tree.read_phylip('./data/medium/medium.phy')

  result = tree.ml_calculations
  unroot_calc.push(result[0])
  unroot_calc_optim.push(result[1])

  # tree = tree.set_edge_length only if the supplied tree does not include edge lengths
  tree = tree.midpointRoot
  result = tree.ml_calculations
  midpoint_calc.push(result[0])
  midpoint_calc_optim.push(result[1])
end

print("Unrooted trees:\n")
print("w/  subtree repeat optimization: # of random trees: #{unroot_calc.count}, mean: #{unroot_calc.mean}, variance: #{unroot_calc.variance}, standard deviation: #{unroot_calc.standard_deviation.round(2)}\n")
print("w/o subtree repeat optimization: # of random trees: #{unroot_calc_optim.count}, mean: #{unroot_calc_optim.mean}, variance: #{unroot_calc_optim.variance}, standard deviation: #{unroot_calc_optim.standard_deviation.round(2)}\n")

print("Midpoint rooted trees:\n")
print("w/  subtree repeat optimization: # of random trees: #{midpoint_calc.count}, mean: #{midpoint_calc.mean}, variance: #{midpoint_calc.variance}, standard deviation: #{midpoint_calc.standard_deviation.round(2)}\n")
print("w/o subtree repeat optimization: # of random trees: #{midpoint_calc_optim.count}, mean: #{midpoint_calc_optim.mean}, variance: #{midpoint_calc_optim.variance}, standard deviation: #{midpoint_calc_optim.standard_deviation.round(2)}\n")


=end
