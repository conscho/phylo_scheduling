require './lib/helper'
require './lib/newick'
require './lib/multi_io'
require './lib/numeric'
require './lib/array'
require './lib/hash'
require 'logger'
require 'parallel'
require 'pp'


# Logger
log_file = File.open("log/#{File.basename(__FILE__, ".rb")}.debug.log", 'a+')
logger = Logger.new(MultiIO.new(STDOUT, log_file))
logger.level = Logger::INFO

# Program parameters
tree_file = "./data/7/parsimony_trees/RAxML_parsimonyTree.T2.RUN.0"
partition_file = './data/7/7.partitions.uniq'
phylip_file =    './data/7/7.phy.uniq'
sample_root = 'midpoint' # Enter the amount of nodes (>= 2) that should be used to root the tree . Enter "all" for all nodes. Enter "midpoint" for midpoint root.
number_of_bins = 4
crop_partitions = 2
crop_sites_per_partition = 6 # Recommended maximum total sites to bins: 20/2 | 14/3 | 12/4

# Initialize
start_time = Time.now
partitions = read_partitions(partition_file)
number_of_taxa, number_of_sites, phylip_data = read_phylip(phylip_file)

# Drop identical sites
if !partition_file.include?("uniq")
  number_of_sites, partitions, phylip_data, partition_file, phylip_file =
      drop_unique_sites(partitions, phylip_data, partition_file, phylip_file, number_of_taxa)
end

logger.info("Program started at #{start_time}")
logger.info("Using parameters: Tree file: #{tree_file}; " \
            "Partition file: #{partition_file}; Phylip File: #{phylip_file}; " \
            "Sample root nodes: #{sample_root}; " \
            "Number of taxa: #{number_of_taxa}; Number of sites: #{number_of_sites}; " \
            "Number of partitions: #{partitions.size}" )



# Crop partitions and list all sites
partitions_limiter = 0
list_of_sites = partitions.map do |partition_name, partition_range|
  partitions_limiter += 1
  next if partitions_limiter > crop_partitions
  (partition_range.begin .. partition_range.begin + crop_sites_per_partition - 1).map {|i| {i => partition_name} }
end.flatten.compact

# Distribute to bins
distributions = list_of_sites.distribute_to_bins(number_of_bins).to_a
logger.info("Checking #{distributions.size} distributions for #{crop_sites_per_partition} sites for #{crop_partitions} partitions over #{number_of_bins} bin")

# Get data
tree = NewickTree.fromFile(tree_file)
tree = tree.add_dna_sequences(phylip_data)

# Midpoint root
tree = tree.set_edge_length.midpoint_root

# Test each distribution and save best distribution
best_distribution = []
best_distribution_operations = Float::INFINITY
distributions.each do |distribution|
  distribution_operations = 0
  distribution.each do |bin|
    # Generate partition distribution
    partitions = Hash.new([])
    bin.each { |site| partitions[site.values[0]] = partitions[site.values[0]] + [site.keys[0]]}

    # Iterate over all partitions
    partitions.each do |partition_name, partition_range|
      result = tree.ml_operations(partition_range)
      distribution_operations += result[1]
    end
  end

  # Check if it the current distribution is a new minimum
  if distribution_operations < best_distribution_operations
    best_distribution = distribution
    best_distribution_operations = distribution_operations
    logger.info("Found new minimum: #{best_distribution_operations} operations")
  end
end


logger.info("Absolute minimum: #{best_distribution_operations}")
logger.info("Distribution: #{best_distribution}")

program_runtime = (Time.now - start_time).duration
logger.info("Programm finished at #{Time.now}. Runtime: #{program_runtime}")