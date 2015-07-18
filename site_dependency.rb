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
data_folder =    './data/1000/'
batches =     { pars: 'parsimony_trees/*parsimonyTree*',
                pars_ml: 'parsimony_trees/*result*',
                rand_ml: 'random_trees/*result*'}
partition_file = '1000.partitions'
phylip_file =    '1000.phy'
sample_root = "midpoint"
sample_trees = 3 # Enter the amount of trees that should be used for statistics.
number_of_processes = 3 # Parallel processing on X cores

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



batches.each do |batch_name, batch_path|

  list_of_trees = Dir.glob(data_folder + batch_path).first(sample_trees)

  csv_output << Parallel.map(list_of_trees, :in_processes => number_of_processes) do |file|

    # Initialize
    tree_output = []

    # Get data
    logger.info("Processing file: #{file}")
    tree = NewickTree.fromFile(file)
    tree = tree.add_dna_sequences(phylip_data)

    # Midpoint root
    tree = tree.set_edge_length.midpoint_root

    # Iterate over all partitions
    partitions.each do |partition_name, partition|

      tree.ml_operations(partition)

      tree.get_site_dependencies(2).flatten.each do |site_dependency|
        tree_output << { batch: batch_name.to_s, tree: file.to_s, partition: partition_name.to_s, dependency: site_dependency }
      end

    end

    tree_output

  end

end


program_runtime = (Time.now - start_time).duration

# Output results to CSV for R
data_file = "output_site_dependency/#{start_time.strftime "%Y-%m-%d %H-%M-%S"} data.csv"
logger.info("Writing data to #{data_file}")
csv_output.flatten.array_of_hashes_to_csv_file(data_file)


# Output parameters to CSV for R
program_parameters_output = { data_folder: data_folder, sample_root: sample_root, sample_trees: sample_trees,
                              number_of_partitions: partitions.size,
                              number_of_taxa: number_of_taxa, number_of_sites: number_of_sites,
                              program_runtime: program_runtime, data_file: data_file,
                              graph_file_name: graph_file_name, number_of_processes: number_of_processes }

parameter_file = "output_site_dependency/#{start_time.strftime "%Y-%m-%d %H-%M-%S"} parameters.csv"
program_parameters_output.to_csv_file(parameter_file)
logger.info("Program parameters written to #{parameter_file}")


logger.info("Programm finished at #{Time.now}. Runtime: #{program_runtime}")