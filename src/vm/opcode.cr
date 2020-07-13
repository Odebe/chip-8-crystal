struct Vm::OpCode
  getter bytes

  def initialize(@bytes : UInt16)
  end

  def to_s
    bytes.to_s(16)
  end

  def &(i)
    bytes & i
  end
end
