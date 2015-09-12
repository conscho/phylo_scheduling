class BinArray
  include Enumerable
  attr_reader :list
  attr_reader :lower_bound_operations
  attr_reader :lower_bound_sites
  attr_reader :rounding_adjustment_operations
  attr_reader :rounding_adjustment_sites

  def initialize(number_of_bins)
    @list = Array.new(number_of_bins) {Bin.new}
  end

  # Apply heuristic according to the input parameter
  def apply_heuristic!(heuristic, remaining_partitions)
    if heuristic == "greedy1"
      self.greedy1_initial!(remaining_partitions)
      self.greedy1_fill!(remaining_partitions)

    elsif heuristic == "greedy2"
      self.greedy2_fill!(remaining_partitions)

    elsif heuristic == "greedy3"
      self.greedy3_fill!(remaining_partitions)

    elsif heuristic == "slice"
      self.slice_fill!(remaining_partitions)

    end
  end


  # Distribute partitions to bins according to the original scheduling algorithm:
  # Fill from small to big without breaking partitions. Stop if a partition doesn't fit anymore.
  # @return [partitions] Remaining partitions that did not feet into the bins.
  def initial_fill!(partitions)
    bin_index = 0
    full_bins = 0
    partitions.size.times do
      if @list[bin_index].size + partitions.first.size <= @lower_bound_operations
        @list[bin_index].add!([partitions.first])
        partitions.drop!(1)

        # Edge case handling for perfect fit
        if @list[bin_index].size == @lower_bound_operations
          full_bins += 1
          @lower_bound_operations -= 1 if full_bins == @list.size - @rounding_adjustment_operations
        end

      else
        break
      end

      bin_index = (bin_index + 1) % @list.size
    end

    partitions
  end

  # Fill one site of each partition into its assigned bin
  def greedy1_initial!(remaining_partitions)
    # Initialize
    site_list = remaining_partitions.sites
    site_index = 0
    partition_index = 0
    total_sites_remaining = remaining_partitions.total_sites
    total_free_space = self.total_free_space

    # Fill each bin starting with the least filled
    self.sort.each_with_index do |bin, bin_index|

      # How many sites need to go into the current bin
      sites_for_bin = ((@lower_bound_operations - bin.size).to_f / total_free_space * total_sites_remaining).floor

      # Pick (random) site of partition, add to bin and drop from "remaining_partitions"
      dropped_partition = remaining_partitions.list.values[partition_index].drop_random_site!
      bin.add!([dropped_partition])

      # Do we need to fill two partitions in this bin?
      if site_list[site_index].values.first != site_list[site_index + sites_for_bin - 1].values.first
        partition_index += 1

        # Pick (random) site of partition, add to bin and drop from "remaining_partitions"
        dropped_partition = remaining_partitions.list.values[partition_index].drop_random_site!
        bin.add!([dropped_partition])

      elsif bin_index < @list.size # Prevent index out of bound
        # Is there a partition switch directly at the beginning of the next bin?
        if site_list[site_index + sites_for_bin - 1].values.first != site_list[site_index + sites_for_bin].values.first
          partition_index += 1
        end
      end

      site_index += sites_for_bin
    end
  end

  # Fill remaining sites where operations are minimal
  def greedy1_fill!(remaining_partitions)
    remaining_partitions.each do |src_partition|
      src_partition.sites.each do |site|

        simulation_result = {}
        self.each do |bin|
          target_partition = bin.list[src_partition.name]
          if target_partition.nil?
            # Simulate creation of partition in current bin since partition does not exist yet
            operations = bin.simulate_add([Partition.new(src_partition.name, [site], src_partition.tree)])
          else
            # Simulate insertion of site into existing partition of current bin
            operations = target_partition.incr_add_sites!([site], true)
          end
          # Find out if bin.size is already larger than the lower bound, then make the operation more costly
          operations = (operations + 100) * 100 if bin.update_size!.size > @lower_bound_operations # FIXME: Very hacky
          simulation_result.merge!({operations => target_partition})
        end

        # Insert at lowest operation cost
        best = simulation_result.min_by {|key, value| key}
        best[1].incr_add_sites!([site])

      end
    end
  end

  # Sequentially add sites to bin with most free space
  def greedy2_fill!(remaining_partitions)
    remaining_partitions.each do |src_partition|
      src_partition.sites.each do |site|

        smallest_bin = self.update_bin_sizes!.min
        target_partition = smallest_bin.list[src_partition.name]
        if target_partition.nil?
          smallest_bin.add!([Partition.new(src_partition.name, [site], src_partition.tree)])
        else
          target_partition.incr_add_sites!([site])
        end

      end
    end
  end

  def greedy3_fill!(remaining_partitions)
    # Initialize index for site selection for each partition in "remaining_partitions"
    partition_indexes = Hash[remaining_partitions.map {|partition| [partition.name, {index: 0, sites: partition.sites.size}]}]

    until partition_indexes.empty?

      # Simulate adding each site and get the respective required operations
      simulation_result = {operations: Float::INFINITY, partition_name: [], partition_sites: []}
      smallest_bin = self.update_bin_sizes!.min
      partition_indexes.each do |partition_name, values|
        target_partition = smallest_bin.list[partition_name]
        operations = if target_partition.nil?
                       Float::INFINITY
                     else
                       target_partition.incr_add_sites!( [ remaining_partitions.list[partition_name].sites[values[:index]] ], true )
                     end

        # Save the partitions with minimal operations
        if operations < simulation_result[:operations]
          simulation_result[:operations] = operations
          simulation_result[:partition_name] = [partition_name]
          simulation_result[:partition_sites] = [values[:sites]]
        elsif operations == simulation_result[:operations]
          simulation_result[:partition_name] << partition_name
          simulation_result[:partition_sites] << values[:sites]
        end
      end

      # If there are multiple solutions get the partition with the most sites
      max_partition_name = simulation_result[:partition_name][simulation_result[:partition_sites].each_with_index.max[1]]

      # Add site or new partition
      target_partition = smallest_bin.list[max_partition_name]
      if target_partition.nil?
        smallest_bin.add!([Partition.new(max_partition_name,
                                         [remaining_partitions.list[max_partition_name].sites[partition_indexes[max_partition_name][:index]]],
                                         remaining_partitions.list[max_partition_name].tree)])
      else
        target_partition.incr_add_sites!( [ remaining_partitions.list[max_partition_name].sites[partition_indexes[max_partition_name][:index]] ] )
      end

      # Get next site or remove partition entry if all sites of partition already distributed
      if partition_indexes[max_partition_name][:index] < partition_indexes[max_partition_name][:sites] - 1
        partition_indexes[max_partition_name][:index] += 1
      else
        partition_indexes.delete(max_partition_name)
      end
    end
  end

  # Use a slicing algorithm to fill the bins. It makes use of the still available space compared to the lower bound in each bin.
  def slice_fill!(remaining_partitions)
    # Total number of sites that need to be distributed
    total_sites_remaining = remaining_partitions.total_sites
    total_free_space = self.total_free_space
    full_bins = 0

    # Fill each bin starting with the least filled
    self.sort.each do |bin|

      # How many sites need to go into the current bin
      number_of_sites = ((@lower_bound_operations - bin.size).to_f / total_free_space * total_sites_remaining).ceil # FIXME: It's probably better to round down and save overflow in last bin

      # Fill "number_of_sites" sites taken from "remaining_partitions" into the bin. The rest stays in "remaining_partitions"
      dropped_partitions = remaining_partitions.drop_sites!(number_of_sites)
      bin.add!(dropped_partitions)

    end
  end

  # Use the original - subtree repeats agnostic - scheduling algorithm to fill the bins. Used as a reference.
  def original_scheduling!(partitions)
    # Phase 1: Sort partitions by sites.site
    partitions.sort_by_sites!

    # Phase 2: Initial filling
    bin_assigner = 0
    full_bins = 0
    partitions.size.times do
      if @list[bin_assigner].total_sites + partitions.first.sites.size <= @lower_bound_sites
        @list[bin_assigner].add!([partitions.first])
        partitions.drop!(1)

        # Edge case handling for perfect fit
        if @list[bin_assigner].total_sites == @lower_bound_sites
          full_bins += 1
          @lower_bound_sites -= 1 if full_bins == @list.size - @rounding_adjustment_sites
        end

      else
        break
      end

      bin_assigner = (bin_assigner + 1) % @list.size
    end

    # Phase 3: Partitioning
    # Fill each bin starting with the least filled
    self.sort_by {|bin| bin.total_sites}.each do |bin|

      # How many sites need to go into the current bin
      number_of_sites = @lower_bound_sites - bin.total_sites

      # Fill the "remaining_partitions" into the bin until the bin is full. Then return the rest.
      dropped_partitions = partitions.drop_sites!(number_of_sites)
      bin.add!(dropped_partitions)

      # Exact fit
      full_bins += 1
      @lower_bound_sites -= 1 if full_bins == @list.size - @rounding_adjustment_sites

    end
  end

  # Optimize according to the selected algorithm
  def optimize!(optimization)
    ## TODO: Empty
  end

  # Total operations of all bins
  def size
    @list.map {|bin| bin.size}.reduce(:+)
  end

  def update_bin_sizes!
    @list.each do |bin|
      bin.update_size!
    end
    self
  end

  # How many sites are there in total over all bins
  def total_sites
    @list.map {|bin| bin.total_sites}.reduce(:+)
  end

  # Free space compared to the lower bound for each bin
  def free_spaces
    @list.map {|bin| @lower_bound_operations - bin.size}
  end

  def average_bin_size
    self.size.to_f / @list.size
  end

  # Total free space over all bins compared to the lower bound
  def total_free_space
    self.free_spaces.reduce(:+)
  end

  # Set lower bound for operations and sites
  def set_lower_bound!(partitions)
    @lower_bound_operations = (partitions.op_optimized_size.to_f / @list.size).ceil
    @rounding_adjustment_operations = @lower_bound_operations * @list.size - partitions.op_optimized_size
    @lower_bound_sites = (partitions.total_sites.to_f / @list.size).ceil
    @rounding_adjustment_sites = @lower_bound_sites * @list.size - partitions.total_sites
  end

  def to_s(option = "none")
    string = "["
    @list.each_with_index {|bin, bin_index| string += "(bin#{bin_index}: #{bin.to_s(option)}), "}
    if string.size > 1
      string[0..-3] + "]"
    else
      "[]"
    end
  end

  def to_csv(description)
    # Iterate over all partitions and add up operations for this bin
    self.each_with_index.map {|bin, bin_index| bin.to_csv({description: description, bin: bin_index, optimum: @lower_bound_operations}) }.flatten
  end

  def each(&block)
    @list.each do |bin|
      if block_given?
        block.call(bin)
      else
        yield bin
      end
    end
  end
end


