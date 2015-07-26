class Array
  def array_of_hashes_to_csv_file(csv_filename="hash.csv")
    require 'csv'
    CSV.open(csv_filename, "wb") do |csv|
      csv << first.keys # adds the attributes name on the first line
      self.each do |hash|
        csv << hash.values
      end
    end
  end

  def array_to_csv_file(csv_filename="list.csv")
    require 'csv'
    CSV.open(csv_filename, "wb") do |csv|
      csv << self
    end
  end


  def distribute_to_bins(bins_left)
    Enumerator.new do |yielder|
      if self.empty?
        yielder.yield([])
      else

        # If there is only one bin left, fill all remaining items in it
        min_elements_in_bin = if bins_left == 1
                                self.size
                              else
                                1
                              end
        # Make sure that there are sufficient items left to not get any empty bins
        max_elements_in_bin = self.size - (bins_left - 1)

        (min_elements_in_bin..max_elements_in_bin).to_a.each do |number_of_elements_in_bin|
          self.drop(1).combination(number_of_elements_in_bin - 1).map { |vs| [self.first] + vs }.each do |values|
            (self - values).distribute_to_bins(bins_left - 1).each do |group|
              yielder.yield([values] + group)
            end
          end
        end
      end
    end
  end

end