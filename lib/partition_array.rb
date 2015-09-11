class PartitionArray
  include Enumerable
  attr_reader :list

  def initialize(partitions_hash)
    @list = []
    partitions_hash.each do |partition_name, partition_sites|
      @list << Partition.new(partition_name, partition_sites)
    end
  end

  def PartitionArray.from_file(file_name)
    partitions_hash = {}
    in_file = File.new(file_name)
    in_file.each do |line|
      match_object = /, ?(?<name>.*) = (?<start>\d+)-(?<end>\d+)/.match(line)
      partitions_hash[(match_object[:name].to_sym)] = ((match_object[:start].to_i - 1) .. (match_object[:end].to_i - 1)).to_a
    end
    in_file.close
    return PartitionArray.new(partitions_hash)
  end

  # Add tree to each partition and calculate operations
  def add_tree!(tree)
    @list.each do |partition|
      partition.add_tree!(tree)
    end
    self
  end

  # Get array of all names of partitions
  def names
    @list.map {|partition| partition.name}
  end

  def op_optimized_size
    @list.map {|partition| partition.op_optimized}.reduce(:+)
  end

  def total_sites
    @list.map {|partition| partition.sites.size}.reduce(:+)
  end

  # Returns an array of hashes with site => partition_name of all containing partitions
  def sites
    @list.map {|partition| partition.sites.each_with_object(partition.name).map {|site, partition_name| {site => partition_name} }}.flatten(1)
  end

  def empty?
    @list.empty?
  end

  # Put the "partition" into "position" overwriting the previous one
  def replace!(position, partition)
    @list[position] = partition
    self
  end

  def add!(partition)
    @list << partition
    self
  end

  # Drops "n" partitions in-place and returns those dropped partitions.
  # @return [dropped_elements] Array of Partitions
  def drop!(n)
    dropped_elements = @list.first(n)
    @list = @list.drop(n)
    return dropped_elements
  end

  # Drop the first partitions that sum up to "n" sites.
  # @return [dropped_partitions] All the partitions(/sites) that have been dropped
  # @param [Integer] n = number of sites
  # @param [boolean] compute = Whether or not ml_operations should be calculated for the dropped partitions
  def drop_sites!(n, compute = true)
    dropped_partitions = []

    until n == 0 || @list.empty? do

      if @list[0].sites.size == n # "n" is as big as the first partition -> drop it
        dropped_partitions << self.drop!(1).first
        n = 0

      elsif @list[0].sites.size > n # "n" is smaller than the first partition -> crop it
        dropped_partitions << @list[0].drop_sites!(n, compute)
        n = 0

      else # "n" is bigger than first partition -> reduce "n" + drop partition
        n -= @list[0].sites.size
        dropped_partitions << self.drop!(1).first

      end

    end
    return dropped_partitions
  end

  # In-place sorting after "op_optimized"
  def sort!
    @list = @list.sort
    self
  end

  # In-place sorting by number of sites per partition
  def sort_by_sites!
    @list = @list.sort_by {|partition| partition.sites.size}
    self
  end

  def size
    @list.size
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

  def to_s
    string = "["
    @list.each {|partition| string += "(#{partition.to_s}), "}
    if string.size > 1
      string[0..-3] + "]"
    else
      "[]"
    end
  end

end


