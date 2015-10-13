class Partition
  include Comparable

  attr_reader :name
  attr_reader :sites
  attr_reader :tree
  attr_reader :tree_cloned
  attr_reader :op_maximum
  attr_reader :op_optimized
  attr_reader :op_savings

  def initialize(name, sites, tree = nil, compute = true)
    @name = name
    @sites = sites
    @op_maximum = 0
    @op_optimized = 0
    @op_savings = 0
    @tree = tree
    @tree_cloned = false
    self.ml_operations! if compute && !tree.nil?
  end

  # Add tree to partition and calculate operations
  def add_tree!(tree, compute = true)
    @tree = tree
    self.ml_operations! if compute
    self
  end

  # Have the ML operations already been calculated?
  def calculated?
    if @op_optimized == 0
      false
    else
      true
    end
  end

  # Any sites left in this partition
  def empty?
    @sites.empty?
  end

  # Update operations for partition
  def ml_operations!
    result = @tree.ml_operations!(@sites)
    @op_maximum = result[:op_maximum]
    @op_optimized = result[:op_optimized]
    @op_savings = result[:op_savings]

    @op_optimized
  end

  def get_site_dependencies_count
    dependencies_count = @tree.site_dependencies_count
    @sites.map {|site| [site, 0]}.to_h.merge(dependencies_count)
  end

  def op_maximum_per_site
    @op_maximum / @sites.size
  end

  # Merge another partition into this one.
  # @return [Integer] How many operations the merge adds to the partition
  def merge!(partition, simulate = false, dirty = false)
    if dirty
      self.add_sites!(partition.sites)
    else
      self.incr_add_sites!(partition.sites, simulate)
    end
  end

  # Add sites to partition and calculate the operations.
  def incr_add_sites!(sites, simulate = false)
    # Get a clean copy of the tree and rerun ml_operations since we do not know what was stored in the tree before
    if @tree_cloned == false
      @tree = DeepClone.clone @tree
      @tree_cloned = true
      self.ml_operations!
    end

    result = @tree.ml_operations!(sites, false, simulate)
    unless simulate
      @sites.push(sites).flatten!
      @op_maximum += result[:op_maximum]
      @op_optimized += result[:op_optimized]
      @op_savings = ((@op_maximum.to_f - @op_optimized.to_f) / @op_maximum.to_f * 100)
    end
    result[:op_optimized]
  end

  # Just add sites don't update tree or operations
  def add_sites!(sites)
    @sites.push(sites).flatten!
    0
  end

  # Drop sites in the beginning of partition
  # @return [Partition] partition with those dropped sites
  def drop_sites!(n, compute = true)
    dropped_sites = @sites.first(n)
    @sites = @sites.drop(n)
    Partition.new(@name, dropped_sites, @tree, compute)
  end

  # Drop sites in the beginning of partition without updating operations
  # @return [Partition] partition with those dropped sites
  def drop_sites(n, compute = true)
    dropped_sites = @sites.first(n)
    Partition.new(@name, dropped_sites, @tree, compute)
  end

  # Delete sites without updating operations.
  # @return [Array of dropped sites]
  def delete_sites!(n)
    deleted_sites = @sites.first(n)
    @sites = @sites.drop(n)
    deleted_sites
  end

  # Delete given sites from partition and update size.
  # @param [Array of sites] sites
  # @param [Boolean] return_partition
  def delete_specific_sites!(sites, return_partition = false)
    sites.each { |site| @sites.delete(site) }
    self.ml_operations!
    Partition.new(@name, sites, @tree, compute = false) if return_partition
  end

  # Delete (determinisitc) random site in partition without updating operations
  def drop_random_site!
    dropped_site = @sites.sample
    @sites.delete(dropped_site)
    return Partition.new(@name, [dropped_site], @tree)
  end

  # Delete site with given index from partition and return it
  def slice!(index)
    @sites.slice!(index)
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