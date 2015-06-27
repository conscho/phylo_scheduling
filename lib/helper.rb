def read_partitions(file_name)
  partitions = []
  model_file = File.new(file_name)
  model_file.each do |line|
    partitions.push(line.match(/(\d+)-(\d+)/).captures.map(&:to_i))
  end
  model_file.close
  return partitions
end