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
end