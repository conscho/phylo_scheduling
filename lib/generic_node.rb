class GenericNode
  attr_accessor :name
  attr_accessor :children
  attr_accessor :parent

  def initialize(name, parent = nil)
    @name = name
    @children = []
    @parent = parent
  end

  def add_child(name)
    @children << GenericNode.new(name, self)
  end

  def find(name)
    found = nil
    if @name == name
      found = self
    else
      @children.each do |child|
        found = child.find(name)
        break if found
      end
    end
    found
  end

  # Return list of nodes in preorder traversal
  def preorder_traversal
    list = [@name]
    list << @children.map { |child| child.preorder_traversal }
  end
end