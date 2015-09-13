class Partition
  include Comparable

  attr_reader :name
  attr_reader :sites
  attr_reader :tree
  attr_reader :op_maximum
  attr_reader :op_optimized
  attr_reader :op_savings

  def initialize(name, sites, tree = nil, compute = true)
    @name = name
    @sites = sites
    if !tree.nil?
      @tree = DeepClone.clone tree
      self.ml_operations! if compute
    end
  end

  # Add tree to partition and calculate operations
  def add_tree!(tree, compute = true)
    @tree = DeepClone.clone tree
    self.ml_operations! if compute
    self
  end

  # Have the ML operations already been calculated?
  def calculated?
    if !@op_optimized.nil?
      true
    else
      false
    end
  end

  def ml_operations!
    result = @tree.ml_operations!(@sites)
    @op_maximum = result[:op_maximum]
    @op_optimized = result[:op_optimized]
    @op_savings = result[:op_savings]

    @op_optimized
  end

  def incr_add_sites!(sites, simulate = false)
    result = @tree.ml_operations!(sites, false, simulate)
    unless simulate
      @sites.push(sites).flatten!
      @op_maximum += result[:op_maximum]
      @op_optimized += result[:op_optimized]
      @op_savings = ((@op_maximum.to_f - @op_optimized.to_f) / @op_maximum.to_f * 100)
    end
    result[:op_optimized]
  end

  # Merge another partition into this one.
  # @return [Integer] How many operations the merge adds to the partition
  def merge!(partition, simulate = false)
    self.incr_add_sites!(partition.sites, simulate)
  end

  # Drop sites in the beginning of partition
  # @return [Partition] partition with those dropped sites
  def drop_sites!(n, compute = true)
    dropped_sites = @sites.first(n)
    @sites = @sites.drop(n)
    Partition.new(@name, dropped_sites, @tree, compute)
  end

  # Drop sites in the beginning of partition
  # @return [Partition] partition with those dropped sites
  def drop_sites(n, compute = true)
    dropped_sites = @sites.first(n)
    Partition.new(@name, dropped_sites, @tree, compute)
  end

  # Delete sites without updating sizes.
  # @return [Array of dropped sites]
  def delete_sites!(n)
    dropped_sites = @sites.first(n)
    @sites = @sites.drop(n)
    dropped_sites
  end

  def drop_random_site!
    dropped_site = @sites.sample
    @sites.delete(dropped_site)
    return Partition.new(@name, [dropped_site], @tree)
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

  # Return new partition containing only {number} sites
  def crop(number)
    Partition.new(@name, @sites.first(number))
  end

  def <=> other
    self.op_optimized <=> other.op_optimized
  end

  def to_s
    "Partition #{@name}, #{self.sites.size} sites"
  end

  def to_csv(hash)
    hash.merge({sites: @sites.size, partition: @name, op_optimized: @op_optimized, op_maximum: @op_maximum})
  end

  def size
    @op_optimized
  end

end