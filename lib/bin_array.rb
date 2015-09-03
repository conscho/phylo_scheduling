class BinArray
  include Enumerable
  attr_reader :list
  attr_reader :bin_target_op_size
  attr_reader :bin_target_sites_size
  attr_reader :rounding_adjustment

  def initialize(number_of_bins)
    @list = Array.new(number_of_bins) {Bin.new}
  end

  def initial_fill(partitions)
    bin_assigner = 0
    full_bins = 0
    partitions.size.times do
      if @list[bin_assigner].size + partitions.first.size <= @bin_target_op_size
        @list[bin_assigner].add!(partitions.first)
        partitions.drop!(1)

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

  def slice_fill(remaining_partitions, option)

    # Total number of sites that need to be distributed
    total_sites_remaining = remaining_partitions.total_sites
    total_free_space = self.total_free_space

    # Fill each bin
    self.each do |bin|

      # How many sites need to go into the current bin
      if option == "operations"
        sites_for_bin = (bin.free_space(bin_target_op_size).to_f / total_free_space * total_sites_remaining).ceil # FIXME: It's probably better to round down and save overflow in last bin
      elsif option == "sites"
        sites_for_bin = bin_target_sites_size - bin.total_sites
      end


      # Fill one bin after the other and drop the part that has been filled into bins already
      until remaining_partitions.empty? do

        if remaining_partitions.first.sites.size == sites_for_bin # partition fits entirely in free space of bin
          bin.add!(remaining_partitions.first, false)
          remaining_partitions.drop!(1)
          break # move to next bin

        elsif remaining_partitions.first.sites.size > sites_for_bin # partition is bigger than free space available
          # Add partial partition to bin
          bin.add!(remaining_partitions.first.crop(sites_for_bin), false)
          remaining_partitions.first.drop_sites!(sites_for_bin)
          break # move to next bin

        else # partition is smaller than open space -> stay in current bin + reduce available space + drop partition
          bin.add!(remaining_partitions.first, false)
          sites_for_bin -= remaining_partitions.first.sites.size
          remaining_partitions.drop!(1)
        end

      end

    end

    self
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

  def add!(partition, calculate_operations = true)
    @list << partition
    @size = @list.map {|element| element.op_optimized}.reduce(:+) if calculate_operations
  end

  def free_space(bin_target_op_size)
    bin_target_op_size - @size
  end

  def ml_operations!(tree)
    @size = @list.map {|partition| partition.ml_operations!(tree)}.reduce(:+)
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


