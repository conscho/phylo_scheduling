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
tree_file = "./data/59/parsimony_trees/RAxML_result.T4.RUN.0"
partition_file = './data/59/59.partitions.uniq'
phylip_file =    './data/59/59.phy.uniq'
sample_root = 'midpoint' # Enter the amount of nodes (>= 2) that should be used to root the tree . Enter "all" for all nodes. Enter "midpoint" for midpoint root.
number_of_bins = 2
crop_partitions = 3
crop_sites_per_partition = 6 # Recommended maximum bins to total sites: 2-20 | 3-14 | 4-12

# Initialize
start_time = Time.now
partitions = read_partitions(partition_file)
number_of_taxa, number_of_sites, phylip_data = read_phylip(phylip_file)
graph_file_name = "graphs/#{phylip_file.scan(/(\w+)\//).join("-")} #{start_time.strftime "%Y-%m-%d %H-%M-%S"}"

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
logger.info("Calculating number of distributions for #{crop_sites_per_partition} sites for #{crop_partitions} partitions over #{number_of_bins} bin")
distributions = list_of_sites.distribute_to_bins(number_of_bins).to_a
logger.info("Result: #{distributions.size} distributions")

# Get data
tree = NewickTree.fromFile(tree_file)
tree = tree.add_dna_sequences(phylip_data)

# Midpoint root
tree = tree.set_edge_length.midpoint_root

# Test each distribution and save best distribution
best_distribution = []
best_dist_operations_maximum = 0
best_dist_operations_optimized = Float::INFINITY
distributions.each_with_index do |distribution, index|
  dist_operations_maximum = 0
  dist_operations_optimized = 0

  distribution.each do |bin|
    bin_operations_maximum = 0
    bin_operations_optimized = 0

    # Generate partition distribution
    partitions = Hash.new([])
    bin.each { |site| partitions[site.values[0]] = partitions[site.values[0]] + [site.keys[0]]}

    # Iterate over all partitions
    partitions.each do |partition_name, partition_range|
      result = tree.ml_operations(partition_range)
      bin_operations_maximum += result[0]
      bin_operations_optimized += result[1]
    end

    # Get the operations count for the largest bin -> bottleneck
    if bin_operations_optimized > dist_operations_optimized
      dist_operations_optimized = bin_operations_optimized
      dist_operations_maximum = bin_operations_maximum
    end

  end

  # Check if it the current distribution has a minimal largest bin
  if dist_operations_optimized < best_dist_operations_optimized
    best_distribution = distribution
    best_dist_operations_optimized = dist_operations_optimized
    best_dist_operations_maximum = dist_operations_maximum
    logger.info("Found new minimum: #{best_dist_operations_optimized} operations in largest bin")
  end

  # Progress indicator
  print "." if index % (distributions.size / 100) == 0
end


best_dist_savings = ((best_dist_operations_maximum-best_dist_operations_optimized).to_f/best_dist_operations_maximum.to_f*100).round(2)
logger.info("Absolute minimum #{best_dist_operations_optimized} with savings of #{best_dist_savings} in largest bin")
logger.info("Distribution: #{best_distribution}")

csv_output = []
best_distribution.each_with_index do |bin, bin_index|
  bin.each_with_index do |element|
    csv_output << {element: element.keys[0], bin: bin_index, partition: element.values[0]}
  end
end

program_runtime = (Time.now - start_time).duration

# Output results to CSV for R
data_file = "output_#{File.basename(__FILE__, ".rb")}/#{start_time.strftime "%Y-%m-%d %H-%M-%S"} data.csv"
logger.info("Writing data to #{data_file}")
csv_output.flatten.array_of_hashes_to_csv_file(data_file)


# Output parameters to CSV for R
program_parameters_output = { phylip_file: phylip_file, sample_root: sample_root,
                              number_of_bins: number_of_bins, crop_partitions: crop_partitions,
                              crop_sites_per_partition: crop_sites_per_partition,
                              best_dist_savings_in_largest_bin: best_dist_savings,
                              program_runtime: program_runtime, data_file: data_file,
                              graph_file_name: graph_file_name}

parameter_file = "output_#{File.basename(__FILE__, ".rb")}/#{start_time.strftime "%Y-%m-%d %H-%M-%S"} parameters.csv"
program_parameters_output.to_csv_file(parameter_file)
logger.info("Program parameters written to #{parameter_file}")


logger.info("Programm finished at #{Time.now}. Runtime: #{program_runtime}")