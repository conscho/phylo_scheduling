require './lib/helper'
require './lib/newick'
require './lib/multi_io'
require './lib/numeric'
require './lib/array'
require './lib/hash'
require 'parallel'


# Program parameters
batches =     { pars: './data/7/parsimony_trees/*parsimonyTree*',
                pars_ml: './data/7/parsimony_trees/*result*',
                rand_ml: './data/7/random_trees/*result*'}
partition_file = './data/7/7.partitions'
phylip_file =    './data/7/7.phy'
sample_root = "midpoint" # Enter the amount of nodes (>= 2) that should be used to root the tree . Enter "all" for all nodes. Enter "midpoint" for midpoint root.
sample_trees = 9 # Enter the amount of trees that should be used for statistics.
compare_with_likelihood = true # Create plot with ratio to likelihood distribution. Only works with RAxML naming of files.
number_of_processes = 3 # Parallel processing on X cores. If 0 multithreading is disabled.
split_partitions = true # Split each partition in the middle

# Initialize
start_time = Time.now
csv_output = []
partitions = read_partitions(partition_file)
number_of_taxa, number_of_sites, phylip_data = read_phylip(phylip_file)
graph_file_name = "graphs/#{phylip_file.scan(/(\w+)\//).join("-")} #{start_time.strftime "%Y-%m-%d %H-%M-%S"}"

# Drop identical sites
unless partition_file.include?("uniq")
  number_of_sites, partitions, phylip_data, partition_file, phylip_file =
      drop_unique_sites(partitions, phylip_data, partition_file, phylip_file, number_of_taxa)
end

puts "Program started at #{start_time}"
puts "Using parameters: Tree files: #{batches}; " \
     "Partition file: #{partition_file}; Phylip File: #{phylip_file}; " \
     "Sample root nodes: #{sample_root}; Sample trees: #{sample_trees}; " \
     "Number of taxa: #{number_of_taxa}; Number of sites: #{number_of_sites}; " \
     "Number of partitions: #{partitions.size}; Number of processes: #{number_of_processes}"


# Get likelihood values also?
likelihoods = read_likelihood(batches) if compare_with_likelihood

batches.each do |batch_name, batch_path|

  list_of_trees = Dir.glob(batch_path).first(sample_trees)

  csv_output << Parallel.map(list_of_trees, :in_processes => number_of_processes) do |file|

    # Initialize
    tree_output = []

    # Get data
    puts "Processing file: #{file}"
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

    root_nodes.each_with_index do |node, root_index|

      # Root tree unless the parameter midpoint root (root_nodes.size == 1) has been chosen
      tree.reroot(node) unless root_nodes.size == 1
      height = tree.height

      # Iterate over all partitions
      partitions.each do |partition_name, partition_range|

        # Split partitions to get a feeling for the efficiency loss
        if split_partitions

          # Split in the middle of each partition
          split_at = partition_range.size / 2

          result_until_split = tree.ml_operations(partition_range.begin .. (partition_range.begin + split_at))
          result_after_split = tree.ml_operations((partition_range.begin + split_at + 1) .. partition_range.end)

          tree_output << { batch: batch_name.to_s, tree: file.to_s, likelihood: likelihood,
                           root_node: root_index.to_s, height: height, partition: partition_name.to_s,
                           operations_maximum: result_until_split[0] + result_after_split[0],
                           operations_optimized: result_until_split[1] + result_after_split[1],
                           ratio_of_savings: (((result_until_split[0] + result_after_split[0]) -
                               (result_until_split[1] + result_after_split[1])).to_f /
                               (result_until_split[0] + result_after_split[0]).to_f * 100),
                           split_partitions: 1 }

        end

        result = tree.ml_operations(partition_range)

        tree_output << { batch: batch_name.to_s, tree: file.to_s, likelihood: likelihood,
                         root_node: root_index.to_s, height: height, partition: partition_name.to_s,
                         operations_maximum: result[0], operations_optimized: result[1],
                         ratio_of_savings: result[2], split_partitions: 0 }

      end

    end

    tree_output

  end

end


program_runtime = (Time.now - start_time).duration

# Output results to CSV for R
data_file = "output_#{File.basename(__FILE__, ".rb")}/#{start_time.strftime "%Y-%m-%d %H-%M-%S"} data.csv"
puts "Writing data to #{data_file}"
csv_output.flatten.array_of_hashes_to_csv_file(data_file)


# Output parameters to CSV for R
program_parameters_output = { phylip_file: phylip_file, sample_root: sample_root, sample_trees: sample_trees,
                              compare_with_likelihood: compare_with_likelihood,
                              number_of_partitions: partitions.size,
                              number_of_taxa: number_of_taxa, number_of_sites: number_of_sites,
                              program_runtime: program_runtime, data_file: data_file,
                              graph_file_name: graph_file_name, number_of_processes: number_of_processes,
                              split_partitions: split_partitions }

parameter_file = "output_#{File.basename(__FILE__, ".rb")}/#{start_time.strftime "%Y-%m-%d %H-%M-%S"} parameters.csv"
program_parameters_output.to_csv_file(parameter_file)
puts "Program parameters written to #{parameter_file}"


puts "Programm finished at #{Time.now}. Runtime: #{program_runtime}"