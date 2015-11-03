class GenericTree
  attr_accessor :root

  def initialize(name)
    @root = GenericNode.new(name)
  end

  def find(name)
    @root.find(name)
  end

  def preorder_traversal
    @root.preorder_traversal.flatten
  end
end