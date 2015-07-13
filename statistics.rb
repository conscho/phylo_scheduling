require './lib/helper'
require './lib/newick'
require './lib/multi_io'
require './lib/numeric'
require './lib/array'
require 'stackprof'
require 'logger'
require 'csv'

# StackProf.run(mode: :cpu, out: 'stackprof-output.dump') do

# Logger
log_file = File.open("log/debug.log", "a")
logger = Logger.new(MultiIO.new(STDOUT, log_file))
logger.level = Logger::INFO

# Program parameters
data_folder =    './data/500/'
batches =     { #pars: "parsimony_trees/*parsimonyTree*",
                pars_ml: "parsimony_trees/*result*",
                rand_ml: "random_trees/*result*"}
partition_file = '500.partitions'
phylip_file =    '500.phy'
sample_root = "midpoint" # Enter the amount of nodes (>= 2) that should be used to root the tree . Enter "all" for all nodes. Enter "midpoint" for midpoint root.
sample_trees = 100 # Enter the amount of trees that should be used for statistics.
height_analysis = true # For each tree get a analysis of height to ratio. Does not make sense for single root node parameter.
compare_with_likelihood = true # Create plot with ratio to likelihood distribution.

# Initialize
start_time = Time.now
csv_output = []
partitions = read_partitions(data_folder + partition_file)
number_of_taxa, number_of_sites, phylip_data = read_phylip(data_folder + phylip_file)
graph_file_name = "graphs/#{data_folder.scan(/\w+/).join(".")} #{start_time.strftime "%Y-%m-%d %H-%M-%S"}"

logger.info("Program started at #{start_time}")
logger.info("Using parameters: Data folder: #{data_folder}; Tree files: #{batches}; " \
            "Partition file: #{partition_file}; Phylip File: #{phylip_file}; " \
            "Sample root nodes: #{sample_root}; Sample trees: #{sample_trees}; " \
            "Number of taxa: #{number_of_taxa}; Number of sites: #{number_of_sites}; " \
            "Number of partitions: #{partitions.size}" )


# Get likelihood values also?
likelihoods = read_likelihood(logger, batches, data_folder) if compare_with_likelihood

batches.each do |batch_name, batch_path|

  Dir.glob(data_folder + batch_path).first(sample_trees).each_with_index do |file, file_index|

    # Get data
    logger.info("Processing file: #{file}")
    tree = NewickTree.fromFile(file)
    tree = tree.add_dna_sequences(phylip_data)

    # Get likelihood for current tree
    likelihood = 0
    if compare_with_likelihood
      match_object = /.*\.(?<prefix>.*)\.RUN\.(?<tree_number>.*)/.match(file)
      likelihood = likelihoods[batch_name.to_s + '-' + match_object[:prefix] + '-' + match_object[:tree_number]]
    end

    # Sample root, midpoint root or root once on all nodes?
    root_nodes = []
    if sample_root == "all"
      root_nodes = tree.nodes
    elsif sample_root == "midpoint"
      tree = tree.set_edge_length.midpoint_root
      root_nodes[0] = tree.root
    else
      root_nodes = tree.nodes.first(sample_root)
    end

    logger.debug("Iterating over #{root_nodes.size} nodes")
    root_nodes.each_with_index do |node, root_index|

      # Root tree unless the parameter midpoint root (root_nodes.size == 1) has been chosen
      tree.reroot(node) unless root_nodes.size == 1
      logger.debug("Rooted at Node #{root_index}: #{node}")

      height = 0
      if height_analysis
        height = tree.height
      end

      # Iterate over all partitions
      partitions.each do |partition_name, partition|
        result = tree.ml_operations(partition)
        operations_maximum = result[0]
        operations_optimized = result[1]
        operations_ratio = ((result[1].to_f / result[0].to_f) * 100)

        csv_output << { batch: batch_name, tree: file, likelihood: likelihood,
                        root_node: root_index, height: height, partition: partition_name,
                        operations_maximum: operations_maximum, operations_optimized: operations_optimized,
                        operations_ratio: operations_ratio }
      end

    end

  end

end

program_runtime = (Time.now - start_time).duration

# Output results to CSV for R
data_file = "#{start_time.strftime "%Y-%m-%d %H-%M-%S"} data.csv"
csv_output.to_csv(data_file)
logger.info("Data written to #{data_file}")

# Output parameters to CSV for R
program_parameters_output = { data_folder: data_folder, sample_root: sample_root, sample_trees: sample_trees,
                               compare_with_likelihood: compare_with_likelihood,
                               height_analysis: height_analysis, number_of_partitions: partitions.size,
                               number_of_taxa: number_of_taxa, number_of_sites: number_of_sites,
                               program_runtime: program_runtime, data_file: data_file,
                               graph_file_name: graph_file_name }

parameter_file = "#{start_time.strftime "%Y-%m-%d %H-%M-%S"} parameters.csv"
CSV.open(parameter_file, "wb") do |csv|
  csv << program_parameters_output.keys
  csv << program_parameters_output.values
end
logger.info("Program parameters written to #{parameter_file}")


logger.info("Programm finished at #{Time.now}. Runtime: #{program_runtime}")

# end