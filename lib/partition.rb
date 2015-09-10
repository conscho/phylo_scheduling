class Partition
  include Comparable

  attr_reader :name
  attr_reader :sites
  attr_reader :tree
  attr_reader :op_maximum
  attr_reader :op_optimized
  attr_reader :op_savings

  def initialize(name, sites, tree = nil)
    @name = name
    @sites = sites
    if tree != nil
      @tree = Marshal.load( Marshal.dump(tree) )
      self.ml_operations!(@tree)
    end
  end

  # Add tree to partition and calculate operations
  def add_tree!(tree)
    @tree = Marshal.load( Marshal.dump(tree) )
    self.ml_operations!(@tree)
    self
  end

  def ml_operations!(tree)
    result = tree.ml_operations!(@sites)
    @op_maximum = result[:op_maximum]
    @op_optimized = result[:op_optimized]
    @op_savings = result[:op_savings]

    @op_optimized
  end

  def incr_add_site(site, simulate = false)
    result = @tree.ml_operations!([site], false, simulate)
    unless simulate
      @sites << site
      @op_maximum += result[:op_maximum]
      @op_optimized += result[:op_optimized]
      @op_savings = ((@op_maximum.to_f - @op_optimized.to_f) / @op_maximum.to_f * 100)
    end
    result[:op_optimized]
  end

  def drop_site!(site)
    @sites.delete(site)
    self
  end

  # Drop sites in the beginning of partition
  # @return [Partition] partition with those dropped sites
  def drop_sites!(n)
    dropped_sites = @sites.first(n)
    @sites = @sites.drop(n)
    return Partition.new(@name, dropped_sites, @tree)
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