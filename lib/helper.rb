def read_partitions(file_name)
  partitions = {}
  in_file = File.new(file_name)
  in_file.each do |line|
    match_object = /, ?(?<name>.*) = (?<start>\d+)-(?<end>\d+)/.match(line)
    partitions[(match_object[:name].to_sym)] = ((match_object[:start].to_i - 1) .. (match_object[:end].to_i - 1))
  end
  in_file.close
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


def read_phylip(file_name)
  number_of_taxa = 0
  number_of_sites = 0
  phylip_data = {}

  in_file = File.new(file_name)
  in_file.each_with_index do |line, index|
    input = line.strip.split(" ")

    if index == 0 # information from first line of file
      number_of_taxa = input[0].to_i
      number_of_sites = input[1].to_i
      next
    end

    if index > number_of_taxa
      if line.strip != ""
        raise "Warning: Non empty line with index > number_of_leaves found in phylip file!"
      end
      next
    end

    phylip_data[(input[0].to_sym)] = input[1]

  end

  in_file.close

  return number_of_taxa, number_of_sites, phylip_data
end

