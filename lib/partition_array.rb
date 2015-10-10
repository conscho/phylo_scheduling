class PartitionArray
  include Enumerable
  attr_reader :list

  def initialize(partitions_hash = {})
    @list = {}
    partitions_hash.each do |partition_name, partition_sites|
      @list[partition_name] = Partition.new(partition_name, partition_sites)
    end
  end

  def PartitionArray.from_file(file_name)
    partitions_hash = {}
    in_file = File.new(file_name)
    in_file.each do |line|
      match_object = /, ?(?<name>.*) = (?<start>\d+)-(?<end>\d+)/.match(line)
      partitions_hash[(match_object[:name])] = ((match_object[:start].to_i - 1) .. (match_object[:end].to_i - 1)).to_a
    end
    in_file.close
    return PartitionArray.new(partitions_hash)
  end

  # Calculate ML operations for given tree for all partitions
  def ml_operations!
    @list.each_value do |partition|
      partition.ml_operations!
    end
    self
  end

  # Add tree to each partition and calculate operations
  def add_tree!(tree, compute = true)
    @list.each_value do |partition|
      partition.add_tree!(tree, compute)
    end
    self
  end

  # Get array of all names of partitions
  def names
    @list.keys
  end

  def op_optimized_size
    @list.each_value.map {|partition| partition.op_optimized}.reduce(0, :+)
  end

  def total_sites
    @list.each_value.map {|partition| partition.sites.size}.reduce(0, :+)
  end

  # Returns an array of hashes with site => partition_name of all containing partitions
  def sites
    @list.map {|partition_name, partition| partition.sites.map {|site| {site => partition_name} }}.flatten(1)
  end

  def empty?
    @list.empty?
  end

  # Delete all partitions that have 0 sites
  def compact!
    @list.delete_if {|partition_name, partition| partition.sites.size == 0}
  end

  # Add partition or extend existing partition if already exists
  def add!(partition, dirty = false)
    if @list[partition.name].nil?
      @list[partition.name] = partition
    else
      @list[partition.name].merge!(partition, simulate = false, dirty)
    end
    self
  end

  # Drops "n" partitions in-place and returns those dropped partitions.
  # @return [dropped_elements] Array of Partitions
  def drop!(n)
    dropped_elements = @list.values.first(n)
    @list = Hash[@list.drop(n)]
    return dropped_elements
  end

  # Drop the first partitions that sum up to "n" sites.
  # @return [dropped_partitions] All the partitions(/sites) that have been dropped
  # @param [Integer] n = number of sites
  # @param [boolean] compute = Whether or not ml_operations should be calculated for the dropped partitions
  def drop_sites!(n, compute = true)
    dropped_partitions = []

    until n == 0 || @list.empty? do

      if @list.values[0].sites.size <= n # "n" is as big as the first partition -> drop it
        n -= @list.values[0].sites.size
        dropped_partitions << self.drop!(1).first

      else # "n" is smaller than the first partition -> crop it
        dropped_partitions << @list.values[0].drop_sites!(n, compute)
        n = 0

      end

    end
    return dropped_partitions
  end

  # Drop the first partitions that sum up to more than "target_operations" operations
  def drop_operations!(target_operations)
    dropped_partitions = []
    operations = 0

    until operations > target_operations || @list.empty? do

      if @list.values[0].op_optimized <= target_operations - operations
        operations += @list.values[0].op_optimized
        dropped_partitions << self.drop!(1).first

      else
        # Create new partition
        partition = @list.values[0].drop_sites!(1)
        operations += partition.op_optimized

        # Add sites to partition
        until operations > target_operations
          sites = @list.values[0].delete_sites!(1)
          operations += partition.incr_add_sites!(sites)
        end

        # Update size of remaining partition or drop if empty
        if @list.values[0].empty?
          self.drop!(1)
        else
          @list.values[0].ml_operations!
        end

        dropped_partitions << partition
      end

    end
    return dropped_partitions
  end

  # Crop partitions for groundtruth calculation
  def crop!(crop_partitions, crop_sites_per_partition)
    @list = Hash[@list.first(crop_partitions)]
    @list = Hash[@list.map do |partition_name, partition|
      [partition_name, partition.crop(crop_sites_per_partition)]
    end]
  end

  # In-place sorting after "op_optimized"
  def sort!
    @list = Hash[@list.sort_by {|partition_name, partition| partition}]
    self
  end

  # In-place sorting by number of sites per partition
  def sort_by_sites!
    @list = Hash[@list.sort_by {|partition_name, partition| partition.sites.size}]
    self
  end

  def size
    @list.size
  end

  def each(&block)
    @list.each_value do |partition|
      if block_given?
        block.call(partition)
      else
        yield partition
      end
    end
  end

  def to_s
    string = "["
    @list.each_value {|partition| string += "(#{partition.to_s}), "}
    if string.size > 1
      string[0..-3] + "]"
    else
      "[]"
    end
  end

end


