class Vm::Stack(T)
  def initialize
    @values = Array(T).new(16, 0)
    @pointer = 0
  end

  def push(v : T) : Nil
    @values[@pointer] = v
    @pointer += 1
  end

  def pop : T
    @pointer -= 1
    @values[@pointer]
  end

  def to_s
    "[Stack] pointer: #{@pointer}, values: #{@values.map { |e| e.to_s(16) }}"
  end
end

