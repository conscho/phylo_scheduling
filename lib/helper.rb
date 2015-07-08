def read_partitions(file_name)
  partitions = []
  model_file = File.new(file_name)
  model_file.each do |line|
    partitions.push(line.match(/(\d+)-(\d+)/).captures.map(&:to_i))
  end
  model_file.close
  return partitions
end

def read_likelihood(logger, tree_files, data_folder)
  # Initialize
  likelihoods = {}
  visited_folders = {}

  tree_files.each do |key, value|
    subfolder_to_visit = /(?<subfolder>\w*)/.match(value)[:subfolder]

    Dir.glob(data_folder + subfolder_to_visit + "/RAxML_info*") do |file|
      logger.debug("Reading likelihoods from file #{file}")

      likelihoods_tree_prefix = /RAxML_info.(?<prefix>.*)/.match(file)[:prefix]

      load_file = File.new(file)
      load_file.each do |line|
        # Get starting tree likelihoods
        match_object = /Inference\[(?<tree_number>\d*).*likelihood (?<likelihood>.*),/.match(line)
        likelihoods[key.to_s + '-' + likelihoods_tree_prefix + '-' + match_object[:tree_number]] = match_object[:likelihood].to_f unless match_object.nil?

        # Get ML tree likelihoods
        match_object = /Inference\[(?<tree_number>\d*).*Likelihood: (?<likelihood>.*) tree/.match(line)
        likelihoods[key.to_s + '_ml' + '-' + likelihoods_tree_prefix + '-' + match_object[:tree_number]] = match_object[:likelihood].to_f unless match_object.nil?
      end

      load_file.close
    end unless visited_folders.has_key?(subfolder_to_visit)

    visited_folders[subfolder_to_visit] = 1
  end

  likelihoods
end