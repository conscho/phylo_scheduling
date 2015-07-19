require './lib/helper'
require './lib/newick'
require './lib/multi_io'
require './lib/numeric'
require './lib/array'
require './lib/hash'
require 'logger'
require 'parallel'


# Logger
log_file = File.open("log/#{File.basename(__FILE__, ".rb")}.debug.log", 'a+')
logger = Logger.new(MultiIO.new(STDOUT, log_file))
logger.level = Logger::INFO

# Program parameters
data_folder =    './data/59/'
batches =     { pars: 'parsimony_trees/*parsimonyTree*',
                pars_ml: 'parsimony_trees/*result*',
                rand_ml: 'random_trees/*result*'}
partition_file = '59.partitions'
phylip_file =    '59.phy'
sample_root = 'midpoint' # Enter the amount of nodes (>= 2) that should be used to root the tree . Enter "all" for all nodes. Enter "midpoint" for midpoint root.
sample_trees = 100 # Enter the amount of trees that should be used for statistics.
height_analysis = true # For each tree get a analysis of height to ratio. Does not make sense for single root node parameter.
compare_with_likelihood = true # Create plot with ratio to likelihood distribution.
number_of_processes = 3 # Parallel processing on X cores
split_partitions = 10 # 0 if no split, otherwise 0 < x < number of sites in partition. If bigger it gets auto corrected.

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
            "Number of partitions: #{partitions.size}; Number of processes: #{number_of_processes}" )


# Get likelihood values also?
likelihoods = read_likelihood(logger, batches, data_folder) if compare_with_likelihood

batches.each do |batch_name, batch_path|

  list_of_trees = Dir.glob(data_folder + batch_path).first(sample_trees)

  csv_output << Parallel.map(list_of_trees, :in_processes => number_of_processes) do |file|

    # Initialize
    tree_output = []

    # Get data
    logger.info("Processing file: #{file}")
    tree = NewickTree.fromFile(file)
    tree = tree.add_dna_sequences(phylip_data)

    # Get likelihood for current tree
    if compare_with_likelihood
      match_object = /.*\.(?<prefix>.*)\.RUN\.(?<tree_number>.*)/.match(file)
      likelihood = likelihoods[batch_name.to_s + '-' + match_object[:prefix] + '-' + match_object[:tree_number]]
    else
      likelihood = 0
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

      height = if height_analysis
                 tree.height
               else
                 0
               end

      # Iterate over all partitions
      partitions.each do |partition_name, partition_range|

        # Split partitions for scheduling statistics
        if split_partitions != 0

          # Check for split_partitions > number of sites for partition
          split_at = if split_partitions >= (partition_range.end - partition_range.begin)
                       partition_range.end - partition_range.begin - 1
                     else
                       split_partitions
                     end

          result_until_split = tree.ml_operations(partition_range.begin .. (partition_range.begin + split_at))
          result_after_split = tree.ml_operations((partition_range.begin + split_at + 1) .. partition_range.end)

          tree_output << { batch: batch_name.to_s, tree: file.to_s, likelihood: likelihood,
                           root_node: root_index.to_s, height: height, partition: partition_name.to_s,
                           operations_maximum: result_until_split[0] + result_after_split[0],
                           operations_optimized: result_until_split[1] + result_after_split[1],
                           operations_ratio: ((result_until_split[1] + result_after_split[1]).to_f/(result_until_split[0] + result_after_split[0]).to_f * 100),
                           split_partitions: split_at }

        end

        result = tree.ml_operations(partition_range)

        tree_output << { batch: batch_name.to_s, tree: file.to_s, likelihood: likelihood,
                         root_node: root_index.to_s, height: height, partition: partition_name.to_s,
                         operations_maximum: result[0], operations_optimized: result[1],
                         operations_ratio: result[2], split_partitions: 0 }

      end

    end

    tree_output

  end

end


program_runtime = (Time.now - start_time).duration

# Output results to CSV for R
data_file = "output/#{start_time.strftime "%Y-%m-%d %H-%M-%S"} data.csv"
csv_output.flatten.array_of_hashes_to_csv_file(data_file)
logger.info("Data written to #{data_file}")

# Output parameters to CSV for R
program_parameters_output = { data_folder: data_folder, sample_root: sample_root, sample_trees: sample_trees,
                              compare_with_likelihood: compare_with_likelihood,
                              height_analysis: height_analysis, number_of_partitions: partitions.size,
                              number_of_taxa: number_of_taxa, number_of_sites: number_of_sites,
                              program_runtime: program_runtime, data_file: data_file,
                              graph_file_name: graph_file_name, number_of_processes: number_of_processes,
                              split_partitions: split_partitions }

parameter_file = "output/#{start_time.strftime "%Y-%m-%d %H-%M-%S"} parameters.csv"
program_parameters_output.to_csv_file(parameter_file)
logger.info("Program parameters written to #{parameter_file}")


logger.info("Programm finished at #{Time.now}. Runtime: #{program_runtime}")