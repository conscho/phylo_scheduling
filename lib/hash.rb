class Hash
  def to_csv_file(csv_filename="hash.csv")
    require 'csv'
    CSV.open(csv_filename, "wb") do |csv|
      csv << self.keys
      csv << self.values
    end
  end
end