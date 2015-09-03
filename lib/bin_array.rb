class BinArray
  include Enumerable
  attr_reader :list
  attr_reader :bin_target_size
  attr_reader :rounding_adjustment

  def initialize(number_of_bins)
    @list = Array.new(number_of_bins) {Bin.new}
  end

  def initial_fill(partitions)
    bin_assigner = 0
    full_bins = 0
    partitions.size.times do
      if @list[bin_assigner].size + partitions.first.size <= @bin_target_size
        @list[bin_assigner].add(partitions.first)
        partitions = partitions.drop(1)

        # edge case handling for perfect fit
        if @list[bin_assigner].size == @bin_target_size
          full_bins += 1
          @bin_target_size -= 1 if full_bins == self.size - @rounding_adjustment
        end

      else
        break
      end

      bin_assigner = (bin_assigner + 1) % self.size
    end

    partitions
  end

  def size
    @list.size
  end

  def set_bin_target_size(total_op_optimized_size)
    @bin_target_size = (total_op_optimized_size.to_f / self.size).ceil
    @rounding_adjustment = @bin_target_size * self.size - total_op_optimized_size
  end

  def to_s
    string = "["
    @list.each_with_index {|bin, bin_index| string += "(bin#{bin_index}: #{bin.to_s}), "}
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
  attr_reader :list
  attr_reader :size

  def initialize
    @list = []
    @size = 0
  end

  def add(partition)
    @list << partition
    @size = @list.map {|element| element.op_optimized}.reduce(:+)
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

  def each(&block)
    @list.each do |partition|
      if block_given?
        block.call(partition)
      else
        yield partition
      end
    end
  end

end


