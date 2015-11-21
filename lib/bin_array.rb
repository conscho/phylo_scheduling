class BinArray
  include Enumerable
  attr_reader :list
  attr_accessor :operations_lower_bound
  attr_accessor :operations_rounding_adjustment
  attr_reader :sites_lower_bound
  attr_reader :sites_rounding_adjustment
  attr_reader :operations_worst_case

  def initialize(number_of_bins)
    @list = Array.new(number_of_bins) { Bin.new }
  end

  # Distribute partitions to bins similar like the original scheduling algorithm:
  # Fill from small to big without breaking partitions. Stop if a partition doesn't fit anymore.
  # @return [partitions] Remaining partitions that did not feet into the bins.
  def adapted_scheduling_initial!(partitions)
    bin_index = 0
    full_bins = 0
    partitions.size.times do
      if @list[bin_index].size + partitions.first.size <= @operations_lower_bound
        @list[bin_index].add!([partitions.first])
        partitions.drop!(1)

        # Edge case handling for perfect fit
        if @list[bin_index].size == @operations_lower_bound
          full_bins += 1
          @operations_lower_bound -= 1 if full_bins == @list.size - @operations_rounding_adjustment
        end

      else
        break
      end

      bin_index = (bin_index + 1) % @list.size
    end
    @list = @list.sort

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
    self.each_with_index do |bin, bin_index|

      # How many sites need to go into the current bin
      sites_for_bin = ((@operations_lower_bound - bin.size).to_f / total_free_space * total_sites_remaining).floor

      # Pick (random) site of partition, add to bin and drop from "remaining_partitions"
      dropped_partition = remaining_partitions.list.values[partition_index].drop_random_site!
      bin.add!([dropped_partition])

      # Do we need to fill two partitions in this bin?
      if site_list[site_index].values.first != site_list[site_index + sites_for_bin - 1].values.first
        partition_index += 1

        # Pick (random) site of partition, add to bin and drop from "remaining_partitions"
        dropped_partition = remaining_partitions.list.values[partition_index].drop_random_site!
        bin.add!([dropped_partition])

      elsif bin_index < @list.size - 1 # Prevent index out of bound
        # Is there a partition switch directly at the beginning of the next bin?
        if site_list[site_index + sites_for_bin - 1].values.first != site_list[site_index + sites_for_bin].values.first
          partition_index += 1
        end
      end

      site_index += sites_for_bin
    end

    remaining_partitions
  end

  # Fill one site of each partition into its assigned bin. Alternative approach.
  def greedy1_initial_alt!(remaining_partitions)

    virtual_remaining_partitions = DeepClone.clone remaining_partitions

    total_sites_remaining = remaining_partitions.total_sites
    total_free_space = self.total_free_space

    # Fill each bin starting with the least filled
    self.each_with_index do |bin, bin_index|

      # How many sites need to go into the current virtual bin
      sites_for_bin = ((@operations_lower_bound - bin.size).to_f / total_free_space * total_sites_remaining).ceil

      # Get partitions that need to go into the current virtual bin
      dropped_partitions = virtual_remaining_partitions.drop_sites!(sites_for_bin, compute = false)

      dropped_partitions.each do |partition|
        # Get site in the middle of partition
        mid_site = partition.sites[partition.sites.size / 2]

        # Actual assignment of site
        dropped_partition = remaining_partitions.list[partition.name].drop_specific_site!(mid_site)
        bin.add!([dropped_partition])
      end
    end

    remaining_partitions
  end

  # Fill one site of each partition into its assigned bin. Alternative approach.
  def greedy1_initial_alt3!(remaining_partitions)
    bin_index = 0
    virtual_size = 0
    remaining_partitions.each do |partition|
      average_site_size = partition.size / partition.sites.size
      z = 1
      while z <= partition.sites.size && bin_index < @list.size
        z_prime = ((@operations_lower_bound - @list[bin_index].size - virtual_size).to_f/average_site_size).ceil
        if z + z_prime + 1 > partition.sites.size
          z_prime = partition.sites.size - z + 1
          bin_is_full = false
          virtual_size = z_prime * average_site_size - @operations_worst_case
        else
          bin_is_full = true
          virtual_size = 0
        end

        # Assign site to bin
        mid_site = partition.sites[z + z_prime / 2 - 1]
        dropped_partition = partition.drop_specific_site!(mid_site)
        @list[bin_index].add!([dropped_partition])

        z += z_prime - 1
        bin_index += 1 if bin_is_full
      end
    end
    remaining_partitions
  end

  # Fill one site of each partition into its assigned bin. Alternative approach.
  def greedy1_initial_alt2!(remaining_partitions)

    virtual_remaining_partitions = DeepClone.clone remaining_partitions

    sites_in_current_partition = 0
    # Fill each bin starting with the least filled
    self.each_with_index do |bin, bin_index|

      free_space = (@operations_lower_bound - bin.size)

      # condition can be equal since the first remaining partition might be split
      dropped_partitions = if virtual_remaining_partitions.first.op_optimized == free_space || (virtual_remaining_partitions.size == 1 && virtual_remaining_partitions.first.op_optimized <= free_space)
                             virtual_remaining_partitions.drop!(1)
                             sites_in_current_partition = 0
                           elsif virtual_remaining_partitions.first.op_optimized < free_space
                             partition = virtual_remaining_partitions.drop!(1).first
                             sites_in_current_partition = virtual_remaining_partitions.first.sites.size
                             space_per_site = (virtual_remaining_partitions.first.op_optimized / sites_in_current_partition).floor
                             [partition,
                              virtual_remaining_partitions.drop_sites!(((free_space - partition.op_optimized).to_f/space_per_site).ceil, compute = false)]
                           else
                             sites_in_current_partition = virtual_remaining_partitions.first.sites.size if sites_in_current_partition == 0
                             space_per_site = (virtual_remaining_partitions.first.op_optimized / sites_in_current_partition).floor
                             virtual_remaining_partitions.drop_sites!((free_space.to_f/space_per_site).ceil, compute = false)
                           end

      # Phase 2: Add site in the middle of each partition to the bin
      dropped_partitions.each do |partition|
        # Get site in the middle of partition
        mid_site = partition.sites[partition.sites.size / 2]

        # Actual assignment of site
        dropped_partition = remaining_partitions.list[partition.name].drop_specific_site!(mid_site)
        bin.add!([dropped_partition])
      end
    end

    remaining_partitions
  end

  # Fill remaining sites where operations are minimal
  def greedy1_fill!(remaining_partitions)
    remaining_partitions.each do |src_partition|
      # Test each site ...
      src_partition.sites.each do |site|

        simulation_result_below_bound = {}
        simulation_result_above_bound = {}
        # ... in each bin ...
        self.each_with_index do |bin, bin_index|
          target_partition = bin.list[src_partition.name]
          if target_partition.nil?
            # Creating a new partition is more costly than the worst case
            operations = @operations_worst_case + 1
          else
            # Simulate insertion of site into existing partition of current bin
            operations = target_partition.incr_add_sites!([site], true)
          end
          # Check if bin.size is smaller than lower_bound. Save simulation_result accordingly to prefer addition below lower_bound.
          if bin.update_size!.size < @operations_lower_bound
            simulation_result_below_bound.merge!({operations => bin_index})
          else
            simulation_result_above_bound.merge!({operations => bin_index})
          end

        end

        # Insert at lowest operation cost
        best = if simulation_result_below_bound.empty?
                 simulation_result_above_bound.min_by { |operations, bin_index| operations }
               else
                 simulation_result_below_bound.min_by { |operations, bin_index| operations }
               end
        target_partition = @list[best[1]].list[src_partition.name]
        if target_partition.nil?
          @list[best[1]].add!([Partition.new(src_partition.name, [site], src_partition.tree)])
        else
          target_partition.incr_add_sites!([site])
        end

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
    partition_indexes = Hash[remaining_partitions.map { |partition| [partition.name, {index: 0, sites: partition.sites.size}] }]

    until partition_indexes.empty?

      # Simulate adding each site and get the respective required operations
      simulation_result = {operations: Float::INFINITY, partition_name: [], partition_sites: []}
      smallest_bin = self.update_bin_sizes!.min
      partition_indexes.each do |partition_name, values|
        target_partition = smallest_bin.list[partition_name]
        operations = if target_partition.nil?
                       Float::INFINITY
                     else
                       target_partition.incr_add_sites!([remaining_partitions.list[partition_name].sites[values[:index]]], true)
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
        target_partition.incr_add_sites!([remaining_partitions.list[max_partition_name].sites[partition_indexes[max_partition_name][:index]]])
      end

      # Get next site or remove partition entry if all sites of partition already distributed
      if partition_indexes[max_partition_name][:index] < partition_indexes[max_partition_name][:sites] - 1
        partition_indexes[max_partition_name][:index] += 1
      else
        partition_indexes.delete(max_partition_name)
      end
    end
  end

  # Get ratio of free space for each bin, then fill remaining partitions based on this ratio and the operations left
  def cut_fill!(remaining_partitions)
    # Fill each bin starting with the least filled
    self.each do |bin|
      # Total number of operations that need to go into this bin
      total_operations_remaining = remaining_partitions.op_optimized_size
      total_free_space = self.total_free_space

      # How many operations need to go into the current bin
      operations_for_bin = [((@operations_lower_bound - bin.size).to_f / total_free_space * total_operations_remaining).ceil,
                            @operations_lower_bound - bin.size].max

      # Fill sites that add up to "operations_for_bin" taken from "remaining_partitions" into the bin.
      # The rest stays in "remaining_partitions".
      dropped_partitions = remaining_partitions.drop_operations!(operations_for_bin)
      bin.add!(dropped_partitions)
    end
  end

  # Use a slicing algorithm to fill the bins. It makes use of the still available space compared to the lower bound in each bin.
  def slice_fill!(remaining_partitions)
    # Total number of sites that need to be distributed
    total_sites_remaining = remaining_partitions.total_sites
    total_free_space = self.total_free_space

    # Fill each bin starting with the least filled
    self.each do |bin|

      # How many sites need to go into the current bin
      number_of_sites = ((@operations_lower_bound - bin.size).to_f / total_free_space * total_sites_remaining).ceil # FIXME: It's probably better to round down and save overflow in last bin

      # Fill "number_of_sites" sites taken from "remaining_partitions" into the bin. The rest stays in "remaining_partitions"
      dropped_partitions = remaining_partitions.drop_sites!(number_of_sites)
      bin.add!(dropped_partitions)
    end
  end


  # Use the original - subtree repeats agnostic - scheduling algorithm to fill the bins. Used as a reference.
  def original_scheduling_initial!(partitions)
    # Phase 1: Sort partitions by sites.size
    partitions.sort_by_sites!

    # Phase 2: Initial filling
    bin_assigner = 0
    full_bins = 0
    partitions.size.times do
      if @list[bin_assigner].total_sites + partitions.first.sites.size <= @sites_lower_bound
        @list[bin_assigner].add!([partitions.first])
        partitions.drop!(1)

        # Edge case handling for perfect fit
        if @list[bin_assigner].total_sites == @sites_lower_bound
          full_bins += 1
          @sites_lower_bound -= 1 if full_bins == @list.size - @sites_rounding_adjustment
        end

      else
        break
      end

      bin_assigner = (bin_assigner + 1) % @list.size
    end
    partitions
  end

  def original_scheduling_fill!(remaining_partitions)
    # Phase 3: Partitioning
    # Fill each bin starting with the least filled
    full_bins = 0 # FIXME: Sloppy implementation. Should get value from initial.
    self.sort_by { |bin| bin.total_sites }.each do |bin|

      # How many sites need to go into the current bin
      number_of_sites = @sites_lower_bound - bin.total_sites

      # Fill the "remaining_partitions" into the bin until the bin is full. Then return the rest.
      dropped_partitions = remaining_partitions.drop_sites!(number_of_sites)
      bin.add!(dropped_partitions)

      # Exact fit
      full_bins += 1
      @sites_lower_bound -= 1 if full_bins == @list.size - @sites_rounding_adjustment

    end
  end


  # Get the names of the partitions that are split
  # @return [array of names]
  def split_partitions
    partition_names = @list.map { |bin| bin.partition_names }.flatten
    partition_names.select { |name| partition_names.index(name) != partition_names.rindex(name) }.uniq
  end

  # Get bins that have the specified "partition_name" in them
  # @return [array of bin objects]
  def bins_with_partition(partition_name)
    @list.select { |bin| bin.has_partition?(partition_name) }
  end

  # Set lower bound for operations and sites
  def set_lower_bound!(partitions)
    @operations_lower_bound = (partitions.op_optimized_size.to_f / @list.size).ceil
    @operations_rounding_adjustment = @operations_lower_bound * @list.size - partitions.op_optimized_size
    @sites_lower_bound = (partitions.total_sites.to_f / @list.size).ceil
    @sites_rounding_adjustment = @sites_lower_bound * @list.size - partitions.total_sites
  end

  def set_operations_worst_case!(partitions)
    @operations_worst_case = partitions.list.values[0].op_maximum_per_site
  end

  # Total operations of all bins
  def size
    @list.map { |bin| bin.size }.reduce(0, :+)
  end

  def average_bin_size
    self.size.to_f / @list.size
  end

  def update_bin_sizes!
    @list.each do |bin|
      bin.update_size!
    end
    self
  end

  # Free space compared to the lower bound for each bin
  def free_spaces
    @list.map { |bin| [@operations_lower_bound - bin.size, 0].max }
  end

  # Total free space over all bins compared to the lower bound
  def total_free_space
    self.free_spaces.reduce(0, :+)
  end

  # How many sites are there in total over all bins
  def total_sites
    @list.map { |bin| bin.total_sites }.reduce(0, :+)
  end

  def to_s(option = "none")
    string = "["
    @list.each_with_index { |bin, bin_index| string += "(bin#{bin_index}: #{bin.to_s(option)}), " }
    if string.size > 1
      string[0..-3] + "]"
    else
      "[]"
    end
  end

  def to_csv(description)
    # Iterate over all partitions and add up operations for this bin
    self.each_with_index.map { |bin, bin_index| bin.to_csv({description: description, bin: bin_index, lower_bound: @operations_lower_bound}) }.flatten
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


