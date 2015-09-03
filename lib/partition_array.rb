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

  def ml_operations!(tree)
    @list.each do |partition|
      partition.ml_operations!(tree)
    end
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

  def empty?
    @list.empty?
  end

  def drop!(n)
    @list = @list.drop(n)
  end

  def sort!
    @list = @list.sort
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




class Partition
  include Comparable

  attr_reader :name
  attr_reader :sites
  attr_reader :op_maximum
  attr_reader :op_optimized
  attr_reader :op_savings

  def initialize(name, sites)
    @name = name
    @sites = sites
  end

  def ml_operations!(tree)
    result = tree.ml_operations(@sites)
    @op_maximum = result[:op_maximum]
    @op_optimized = result[:op_optimized]
    @op_savings = result[:op_savings]

    @op_optimized
  end

  # Drop sites in the beginning of partition
  def drop_sites!(number)
    @sites = @sites.drop(number)
  end

  # Delete site from partition and return it
  def slice!(position)
    @sites.slice!(position)
  end

  # Add site to the end
  def push!(site)
    @sites = @sites.push(site)
  end

  # Add site to the beginning
  def unshift!(site)
    @sites = @sites.unshift(site)
  end

  # Return new partition containing of sites
  def crop(number)
    Partition.new(@name, @sites.first(number))
  end

  def <=> other
    self.op_optimized <=> other.op_optimized
  end

  def to_s
    "Partition #{@name}, #{self.sites.size} elements"
  end

  def size
    @op_optimized
  end

end