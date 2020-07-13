class Vm::Memory
  getter values

  def initialize
    @values = Array(UInt8).new(4096, 0)
  end

  def size
    @values.size
  end

  def [](i)
    @values[i]
  end

  def [](r : Range(UInt16, UInt16))
    @values[r]
  end

  def []=(i , v : UInt8)
    @values[i] = v
  end
end
