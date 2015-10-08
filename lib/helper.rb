def read_likelihood(batches)
  # Initialize
  likelihoods = {}
  visited_folders = {}

  batches.each do |batch_name, batch_path|
    subfolder_to_visit = /(?<subfolder>.*\/)/.match(batch_path)[:subfolder]

    Dir.glob(subfolder_to_visit + 'RAxML_info*') do |file|

      likelihoods_tree_prefix = /RAxML_info.(?<prefix>.*)/.match(file)[:prefix]

      load_file = File.new(file)
      load_file.each do |line|
        # Get starting tree likelihoods
        match_object = /Inference\[(?<tree_number>\d*).*likelihood (?<likelihood>.*),/.match(line)
        likelihoods[batch_name + '-' + likelihoods_tree_prefix + '-' + match_object[:tree_number]] = match_object[:likelihood].to_f unless match_object.nil?

        # Get ML tree likelihoods
        match_object = /Inference\[(?<tree_number>\d*).*Likelihood: (?<likelihood>.*) tree/.match(line)
        likelihoods[batch_name + '_ml' + '-' + likelihoods_tree_prefix + '-' + match_object[:tree_number]] = match_object[:likelihood].to_f unless match_object.nil?
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
    input = line.strip.split(' ')

    if index == 0 # information from first line of file
      number_of_taxa = input[0].to_i
      number_of_sites = input[1].to_i
      next
    end

    if index > number_of_taxa
      if line.strip != ''
        raise 'Warning: Non empty line with index > number_of_leaves found in phylip file!'
      end
      next
    end

    phylip_data[(input[0].to_sym)] = input[1]

  end

  in_file.close

  return number_of_taxa, number_of_sites, phylip_data
end


def drop_unique_sites(partitions, phylip_data, partition_file, phylip_file, number_of_taxa)

  # Remove duplicates per partition
  all_sites = phylip_data.values.map {|taxa| taxa.split('') }.transpose
  uniq_sites = partitions.map { |partition| all_sites[(partition.sites.first .. partition.sites.last)].uniq }

  # Calculate new array of sites that are in each partition
  start_partition = -1
  reduced_partitions_sites = uniq_sites.map do |partition|
    reduced_partition_sites = ((start_partition + 1) .. (start_partition + partition.size)).to_a
    start_partition += partition.size
    reduced_partition_sites
  end
  reduced_number_of_sites = start_partition + 1

  # Create partitions hash and create new PartitionsArray Object
  reduced_partitions = PartitionArray.new(Hash[partitions.names.zip(reduced_partitions_sites)])

  # Save phylip data
  reduced_phylip_data = Hash[phylip_data.keys.zip(uniq_sites.flatten(1).transpose.map {|taxa| taxa.join})]

  # Save reduced data to disk
  reduced_partition_file = partition_file + '.uniq'
  file = File.new(reduced_partition_file, 'w')
  reduced_partitions.each do |partition|
    file.write("DNA, #{partition.name} = #{partition.sites.first + 1}-#{partition.sites.last + 1}\n")
  end
  file.close

  reduced_phylip_file = phylip_file + '.uniq'
  file = File.new(reduced_phylip_file, 'w')
  file.write("#{number_of_taxa} #{reduced_number_of_sites}\n")
  reduced_phylip_data.each do |taxa_name, taxa_nucleotides|
    file.write("#{taxa_name} #{taxa_nucleotides}\n")
  end
  file.close
  puts "Removed identical sites from partition and phylip file and saved to #{reduced_partition_file} and #{reduced_phylip_file}"

  return reduced_number_of_sites, reduced_partitions, reduced_phylip_data, reduced_partition_file, reduced_phylip_file
end

# Apply heuristic according to the input parameter
def apply_heuristic(heuristic, optimization_options, bins_master, partitions_master, tree_master)
  csv_output = []

  puts "Applying heuristic #{heuristic}"

  # Get clean data
  bins = DeepClone.clone bins_master
  partitions = DeepClone.clone partitions_master

  # Initial fill: Fill sorted partitions into bins as far as possible without breaking the partitions
  remaining_partitions = if heuristic.include?('orig_sched')
                           bins.original_scheduling_initial!(partitions)
                         else
                           bins.adapted_scheduling_initial!(partitions)
                         end

  if heuristic.include?('orig-sched')
    bins.original_scheduling_fill!(remaining_partitions)
    optimization_options = [] # Don't run optimization for the original scheduling algorithm

  elsif heuristic.include?('grdtruth')
    list_of_sites = remaining_partitions.map do |partition|
      partition.sites.map {|i| {i => partition.name} }
    end.flatten.compact

    # Distribute to bins
    puts "Distributing #{list_of_sites.size} sites to #{bins.list.size} bins"
    distributions = list_of_sites.distribute_to_bins(bins.list.size).to_a
    puts "Groundtruth: #{distributions.size} total possible distributions"


    # Test each distribution and save best distribution
    results = Parallel.map(distributions, :in_processes => 0, :progress => "Checking all distributions") do |distribution|
      dist_operations_maximum = 0
      dist_operations_optimized = 0

      # Iterate over each bin of the current distribution
      distribution.each_index do |bin_index|
        bin_operations_maximum = 0
        bin_operations_optimized = 0

        # Add sites from initial_fill
        bin_builder = Hash.new([])
        bins.list[bin_index].each do |partition|
          bin_builder[partition.name] += partition.sites
        end
        # Convert sites array to partitions array for current bin
        distribution[bin_index].each do |site|
          bin_builder[site.values[0]] += [site.keys[0]]
        end
        distribution[bin_index] = bin_builder

        # Iterate over all partitions and add up operations for this bin
        distribution[bin_index].each do |partition_name, partition_range|
          result = tree_master.ml_operations!(partition_range)
          bin_operations_maximum += result[:op_maximum]
          bin_operations_optimized += result[:op_optimized]
        end

        # Get the operations count for the largest bin of the current distribution -> bottleneck
        if bin_operations_optimized > dist_operations_optimized
          dist_operations_optimized = bin_operations_optimized
          dist_operations_maximum = bin_operations_maximum
        end

      end

      [dist_operations_optimized, dist_operations_maximum, distribution]
    end

    minimum = results.min_by(&:first)

    bins = BinArray.new(bins.list.size)
    minimum[2].each_with_index do |bin, bin_index|
      bins.list[bin_index].add!(PartitionArray.new(bin).add_tree!(tree_master))
    end

    optimization_options = [] # Don't run optimization for the groundtruth

  elsif heuristic.include?('grdy1')
    bins.greedy1_initial!(remaining_partitions)
    bins.greedy1_fill!(remaining_partitions)
    optimization_options = Array.new(optimization_options).push('*2')

  elsif heuristic.include?('grdy2')
    bins.greedy2_fill!(remaining_partitions)

  elsif heuristic.include?('grdy3')
    bins.greedy3_fill!(remaining_partitions)

  elsif heuristic.include?('slice')
    bins.slice_fill!(remaining_partitions)

  elsif heuristic.include?('slide')
    bins.slide_fill!(remaining_partitions)
    optimization_options = Array.new(optimization_options).push('*2')

  end

  csv_output << bins.to_csv(heuristic)

  # Apply optimization
  optimization_options.each do |optimization|
    csv_output << apply_optimization(bins, bins_master, partitions_master, tree_master, heuristic, optimization)
  end

  csv_output
end

def apply_optimization(bins, bins_master, partitions_master, tree_master, heuristic, optimization)
  puts "Applying optimization #{optimization} for #{heuristic}"
  csv_output = []

  if optimization == 'low-dep'
    bins = DeepClone.clone bins

      partitions_for_redistribution = PartitionArray.new()
      # Get split partitions
      split_partition_names = bins.split_partitions

      bins.each do |bin|
        # Get split partitions per bin
        bin.find_partitions(split_partition_names).each do |split_partition|
          # Get bottom 20% (but at least a count of 10) sites sorted by dependencies count
          site_dependencies = split_partition.get_site_dependencies_count
          min_sites = Hash[site_dependencies.min_by([site_dependencies.size / 5, [site_dependencies.size, 10].min].max) {|site, count| count}].keys
          partitions_for_redistribution.add!(split_partition.delete_specific_sites!(min_sites, true), dirty = true)
        end
      end
      # Define current bins average as lower bound
      backup_lower_bound = bins.operations_lower_bound
      bins.operations_lower_bound = bins.average_bin_size
      # Execute greedy 1
      bins.greedy1_fill!(partitions_for_redistribution)
      bins.operations_lower_bound = backup_lower_bound

      csv_output << bins.to_csv("#{heuristic}_#{optimization}")

    csv_output << apply_optimization(bins, nil, nil, nil, "#{heuristic}_#{optimization}", 'red-max')


  elsif optimization == 'red-max'
    bins = DeepClone.clone bins

    split_partition_names = bins.split_partitions

    bins.list.size.times do
      max_bin = bins.max

      # Get split partitions in the largest bin
      max_bin.find_partitions(split_partition_names).each do |partition|
        # Get sites and their dependency count
        site_dependencies = partition.get_site_dependencies_count

        # Get other bins that have the same split partition
        bins.bins_with_partition(partition.name).sort.each do |bin|
          next if bins.average_bin_size < bin.size

          # Get number of sites that should be moved based on operations worst case
          n = ((bins.average_bin_size - bin.size).to_f / bins.operations_worst_case).floor

          # Move n sites with minimum dependencies to that bin
          min_sites = Hash[site_dependencies.min_by(n) {|site, count| count}].keys
          min_sites.each {|site| site_dependencies.delete(site)}
          partition.delete_specific_sites!(min_sites)
          bin.add!([Partition.new(partition.name, min_sites, partition.tree, compute = false)])
          if partition.empty?
            max_bin.delete!(partition)
            break
          end
        end
      end
      bins.update_bin_sizes!
    end

    csv_output << bins.to_csv("#{heuristic}_#{optimization}")

  elsif optimization == '*2'
    average_bin_size = bins.average_bin_size

    # Get clean data
    bins = DeepClone.clone bins_master
    partitions = DeepClone.clone partitions_master

    # Apply new lower_bound
    backup_lower_bound = bins.operations_lower_bound
    backup_rounding_adjustment = bins.operations_rounding_adjustment
    bins.operations_lower_bound = average_bin_size
    bins.operations_rounding_adjustment = 0

    # Rerun respective heuristic
    remaining_partitions = bins.adapted_scheduling_initial!(partitions)
    if heuristic.include?('grdy1')
      bins.greedy1_initial!(remaining_partitions)
      bins.greedy1_fill!(remaining_partitions)
    elsif heuristic.include?('slide')
      bins.slide_fill!(remaining_partitions)
    end

    # Restore original lower_bound
    bins.operations_lower_bound = backup_lower_bound
    bins.operations_rounding_adjustment = backup_rounding_adjustment

    csv_output << bins.to_csv("#{heuristic}_#{optimization}")


    # Apply further optimizations on top
    ['low-dep', 'red-max'].each do |further_optimization|
      csv_output << apply_optimization(bins, nil, nil, nil, "#{heuristic}_#{optimization}", further_optimization)
    end

  end


  csv_output
end