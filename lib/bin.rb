class Bin
  include Enumerable
  include Comparable
  attr_reader :list
  attr_reader :size

  def initialize
    @list = {}
    @size = 0
  end

  # Add (array of) partitions to this bin. Merge with existing partitions if they exist.
  def add!(partitions)
    partitions.each do |src_partition|
      target_partition = @list[src_partition.name]
      if !target_partition.nil?
        @size += target_partition.merge!(src_partition)
      else
        src_partition.ml_operations! unless src_partition.calculated?
        @list[src_partition.name] = src_partition
        @size += src_partition.op_optimized
      end
    end
    self
  end

  # Simulate adding (array of) partitions to this bin. Merge with existing partitions if they exist.
  # @return [Integer] Operations that would be added to the bin if you add these partitions
  def simulate_add(partitions)
    operations = 0
    partitions.each do |src_partition|
      target_partition = @list[src_partition.name]
      if !target_partition.nil?
        operations += target_partition.merge!(src_partition, true)
      else
        src_partition.ml_operations! unless src_partition.calculated?
        operations += src_partition.op_optimized
      end
    end

    operations
  end

  def update_size!
    @size = @list.each_value.map {|partition| partition.op_optimized}.reduce(0, :+)
    self
  end

  def partition_names
    @list.keys
  end

  # Returns the partitions that match the given names "partitions"
  def find_partitions(partitions)
    partitions.map { |partition_name| @list[partition_name] }.compact
  end

  # Does the bin have the given partition name in it?
  def has_partition?(partition_name)
    if @list.keys.include?(partition_name)
      true
    else
      false
    end
  end

  def total_sites
    if @list.empty?
      0
    else
      @list.each_value.map {|partition| partition.sites.size}.reduce(0, :+)
    end
  end

  def to_s(option = "none")
    if option == "fill_level"
      "[size: #{@size}, partitions: #{@list.size}, sites: #{self.total_sites}]"
    else
      string = "[size: #{@size}, partitions: "
      @list.each_value {|partition| string += "(#{partition.to_s}), "}
      if string.size > 1
        string[0..-3] + "]"
      else
        "[]"
      end
    end
  end

  def to_csv(hash)
    @list.each_value.map {|partition| partition.to_csv(hash)}
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

  def <=> other
    self.size <=> other.size
  end

end


