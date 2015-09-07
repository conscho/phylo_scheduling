class BinArray
  include Enumerable
  attr_reader :list
  attr_reader :bin_target_op_size
  attr_reader :bin_target_sites_size
  attr_reader :rounding_adjustment

  def initialize(number_of_bins)
    @list = Array.new(number_of_bins) {Bin.new}
  end

  def initial_fill!(partitions)
    bin_assigner = 0
    full_bins = 0
    partitions.size.times do
      if @list[bin_assigner].size + partitions.first.size <= @bin_target_op_size
        @list[bin_assigner].add!(partitions.first)
        partitions = partitions.drop(1)

        # edge case handling for perfect fit
        if @list[bin_assigner].size == @bin_target_op_size
          full_bins += 1
          @bin_target_op_size -= 1 if full_bins == self.size - @rounding_adjustment
        end

      else
        break
      end

      bin_assigner = (bin_assigner + 1) % self.size
    end

    partitions
  end

  def greedy_initial_fill!(remaining_partitions, tree, option)
    # TODO: How to make the method not "in-place"?

    # Initialize loop variables
    site_list = remaining_partitions.sites
    index = 0
    partition_index = 0
    # Total number of sites that need to be distributed
    total_sites_remaining = remaining_partitions.total_sites
    total_free_space = self.total_free_space

    # Fill each bin starting with the least filled
    self.sort.each_with_index do |bin, bin_index|

      # How many sites need to go into the current bin
      if option == "operations"
        sites_for_bin = (bin.free_space(bin_target_op_size).to_f / total_free_space * total_sites_remaining).floor
      elsif option == "sites"
        sites_for_bin = bin_target_sites_size - bin.total_sites
      end

      # Pick (random) site of partition, add to bin and drop from remaining sites
      site_picker = remaining_partitions.list[partition_index].sites.sample
      bin.add!(Partition.new(remaining_partitions.list[partition_index].name, [site_picker], tree), false)
      remaining_partitions = remaining_partitions.replace(partition_index, remaining_partitions.list[partition_index].drop_site!(site_picker))

      if site_list[index].values.first != site_list[index + sites_for_bin - 1].values.first
        partition_index += 1
        # Pick (random) site of partition, add to bin and drop from remaining sites
        site_picker = remaining_partitions.list[partition_index].sites.sample
        bin.add!(Partition.new(remaining_partitions.list[partition_index].name, [site_picker], tree), false)
        remaining_partitions = remaining_partitions.replace(partition_index, remaining_partitions.list[partition_index].drop_site!(site_picker))
      elsif bin_index < self.size # Prevent index out of bound
        if site_list[index + sites_for_bin - 1].values.first != site_list[index + sites_for_bin].values.first
          partition_index += 1
        end
      end

      index += sites_for_bin
    end
  end

  def greedy_fill!(remaining_partitions)
    remaining_partitions.each do |src_partition|
      src_partition.sites.each do |site|

        simulation_result = {}
        self.each do |bin|
          bin.each do |target_partition|
            if target_partition.name == src_partition.name
              # Simulate insert of site into bin
              operations = target_partition.incr_add_site(site, true)
              bin = bin.ml_operations!(nil, false)
              operations = operations * 10 + 100 if bin.size > @bin_target_op_size
              simulation_result.merge!({operations => target_partition})
            end
          end
        end
        # Insert at lowest operation cost
        best = simulation_result.min_by {|key, value| key}
        best[1].incr_add_site(site)

      end
    end
  end


  def slice_fill!(remaining_partitions, option)
    # TODO: How to make the method not "in-place"?

    # Total number of sites that need to be distributed
    total_sites_remaining = remaining_partitions.total_sites
    total_free_space = self.total_free_space

    # Fill each bin starting with the least filled
    self.sort.each do |bin|

      # How many sites need to go into the current bin
      if option == "operations"
        sites_for_bin = (bin.free_space(bin_target_op_size).to_f / total_free_space * total_sites_remaining).ceil # FIXME: It's probably better to round down and save overflow in last bin
      elsif option == "sites"
        sites_for_bin = bin_target_sites_size - bin.total_sites
      end


      # Fill one bin after the other and drop the part that has been filled into bins already
      until remaining_partitions.empty? do

        if remaining_partitions.first.sites.size == sites_for_bin # partition fits entirely in free space of bin
          bin = bin.add(remaining_partitions.first, false)
          remaining_partitions = remaining_partitions.drop(1)
          break # move to next bin

        elsif remaining_partitions.first.sites.size > sites_for_bin # partition is bigger than free space available
          # Add partial partition to bin
          bin = bin.add(remaining_partitions.first.crop(sites_for_bin), false)
          remaining_partitions = remaining_partitions.replace(0, remaining_partitions.first.drop_sites(sites_for_bin))
          break # move to next bin

        else # partition is smaller than open space -> stay in current bin + reduce available space + drop partition
          bin = bin.add(remaining_partitions.first, false)
          sites_for_bin -= remaining_partitions.first.sites.size
          remaining_partitions = remaining_partitions.drop(1)
        end

      end

    end
  end

  def slide_distribution!
    # TODO: Check whether the bins have the correct sizes. Maybe complicated/expensive
    # FIXME: Very hacky...
    (@list.size - 1).times do |bin_index|

      if @list[bin_index] < @list[bin_index + 1]
        @list[bin_index].last.push!(@list[bin_index + 1].last.slice!(0))
      elsif @list[bin_index] > @list[bin_index + 1]
        @list[bin_index + 1].last.unshift!(@list[bin_index].last.slice!(-1))
      end

    end
  end

  def size
    @list.size
  end

  def free_spaces
    @list.map {|bin| bin.free_space(bin_target_op_size)}
  end

  def average_bin_size
    @list.map {|bin| bin.size}.reduce(:+).to_f / self.size
  end

  def total_free_space
    self.free_spaces.reduce(:+)
  end

  def set_bin_target_op_size!(total_op_optimized_size)
    @bin_target_op_size = (total_op_optimized_size.to_f / self.size).ceil
    @rounding_adjustment = @bin_target_op_size * self.size - total_op_optimized_size
  end

  def set_bin_target_sites_size!(total_sites)
    @bin_target_sites_size = (total_sites.to_f / self.size).ceil
  end

  def ml_operations!(tree)
    @list.each do |bin|
      bin.ml_operations!(tree)
    end
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
    self.each_with_index.map {|bin, bin_index| bin.to_csv({description: description, bin: bin_index, optimum: @bin_target_op_size}) }.flatten
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



class Bin
  include Enumerable
  include Comparable
  attr_reader :list
  attr_reader :size

  def initialize
    @list = []
    @size = 0
  end

  def add(partition, calculate_operations = true)
    self.dup.add!(partition, calculate_operations)
  end

  def add!(partition, calculate_operations = true)
    @list << partition
    @size = @list.map {|element| element.op_optimized}.reduce(:+) if calculate_operations
    self
  end

  def free_space(bin_target_op_size)
    bin_target_op_size - @size
  end

  def ml_operations!(tree, compute = true)
    if compute
      @size = @list.map {|partition| partition.ml_operations!(tree)}.reduce(:+)
    else
      @size = @list.map {|partition| partition.op_optimized}.reduce(:+)
    end
    self
  end

  def last
    @list.last
  end

  def total_sites
    self.map {|partition| partition.sites.size}.reduce(:+)
  end

  def to_s(option = "none")
    if option == "fill_level"
      "[size: #{@size}, partition: #{@list.size}, sites: #{self.total_sites}]"
    else
      string = "[size: #{@size}, partitions: "
      @list.each {|partition| string += "(#{partition.to_s}), "}
      if string.size > 1
        string[0..-3] + "]"
      else
        "[]"
      end
    end
  end

  def to_csv(hash)
    self.map {|partition| partition.to_csv(hash)}
  end

  def each(&block)
    @list.each do |partition|
      if block_given?
        block.call(partition)
      else
        yield partition
      end
    end
  end

  def <=> other
    self.size <=> other.size
  end

end


