class Vm::Registers(T)
  getter values

  def initialize
    @values = Array(T).new(16, 0)
  end

  def [](i)
    @values[i]
  end

  def []=(i, v : T)
    @values[i] = v
  end

  def [](r : Range(UInt8, UInt8))
    @values[r]
  end

  def to_s
    @values.map_with_index { |e, i| "v#{i}[#{e}]" }.join(", ")
  end
end
