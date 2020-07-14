
class Vm::Interpreter
  @i : UInt16
  @start_p : UInt16
  @font_start_p : UInt16
  @pc : UInt16
  @delay_timer : UInt8
  @audio_timer : UInt8

  FONTSET = [
    0xF0, 0x90, 0x90, 0x90, 0xF0, # 0
    0x20, 0x60, 0x20, 0x20, 0x70, # 1
    0xF0, 0x10, 0xF0, 0x80, 0xF0, # 2
    0xF0, 0x10, 0xF0, 0x10, 0xF0, # 3
    0x90, 0x90, 0xF0, 0x10, 0x10, # 4
    0xF0, 0x80, 0xF0, 0x10, 0xF0, # 5
    0xF0, 0x80, 0xF0, 0x90, 0xF0, # 6
    0xF0, 0x10, 0x20, 0x40, 0x40, # 7
    0xF0, 0x90, 0xF0, 0x90, 0xF0, # 8
    0xF0, 0x90, 0xF0, 0x10, 0xF0, # 9
    0xF0, 0x90, 0xF0, 0x90, 0x90, # A
    0xE0, 0x90, 0xE0, 0x90, 0xE0, # B
    0xF0, 0x80, 0x80, 0x80, 0xF0, # C
    0xE0, 0x90, 0x90, 0x90, 0xE0, # D
    0xF0, 0x80, 0xF0, 0x80, 0xF0, # E
    0xF0, 0x80, 0xF0, 0x80, 0x80  # F
  ]

  def initialize(@file : File)
    @stack = Vm::Stack(UInt16).new
    @registers = Vm::Registers(UInt8).new
    @memory = Vm::Memory.new
    @keyboard = Vm::Keyboard.new

    @video = Vm::Video.new
    @audio_timer = 0_u8
    @delay_timer = 0_u8
    @i = 0_u16
    @start_p = 0x200_u16
    @font_start_p = (@start_p - FONTSET.size).to_u16
    @pc = @start_p.to_u16

    load_fontset!
  end

  def load_fontset!
    FONTSET.each_with_index do |font_byte, index|
      mem_p = @font_start_p + index
      @memory[mem_p] = font_byte.to_u8
    end
  end

  def char_font_p(char)
    @font_start_p + (char * 5)
  end

  # def running?
  #   (@pc - @start_p) < @file.size
  # end

  def load_program!: Nil
    @file.rewind
    (0...@file.size).each do |i|
      @memory[@start_p + i] = @file.read_bytes(UInt8, IO::ByteFormat::BigEndian)
    end
  end

  # stealing go brrr (thanks https://github.com/mattrberry/chip-8 for good practices!)
  def run! : Nil
    repeat(hz: 60, in_fiber: true) { timers_cycle }
    repeat(hz: 500) { cpu_cycle }
  end

  def log(str)
    # puts "[#{@pc.to_s(16)}] [I: #{@i}] [T: #{@delay_timer}][Reg: #{@registers.to_s}] #{str.to_s}"
  end

  def repeat(hz : Int, &block)
    loop do
      start_time = Time.utc
      block.call
      end_time = Time.utc

      next_cycle = start_time + Time::Span.new(nanoseconds: (1_000_000_000 / hz).to_i)
      sleep next_cycle - end_time if next_cycle > end_time
    end
  end

  def repeat(hz : Int, in_fiber : Bool, &block)
    if in_fiber
      spawn do
        repeat hz, &block
      end
    else
      repeat hz, &block
    end
  end

  def process_(opcode) : Nil
    kk = opcode & 0x00FF
    nnn = opcode & 0x0FFF

    x = (opcode & 0x0F00) >> 8
    y = (opcode & 0x00F0) >> 4
    n = opcode & 0x000F

    case opcode & 0xF000
    when 0x0000
      case opcode & 0x000F
      when 0x0000 
        @video.clear!
      when 0x000E 
        @pc = @stack.pop
      end
      next_code!
    when 0x1000 
      @pc = nnn
    when 0x2000
      @stack.push @pc
      @pc = nnn
    when 0x3000 
      @registers[x] == kk ? skip_next_code! : next_code!
    when 0x4000 
      @registers[x] != kk ? skip_next_code! : next_code!
    when 0x5000
      case opcode & 0x000F
      when 0x0000 
        @registers[x] == @registers[y] ? skip_next_code! : next_code!
      end
    when 0x6000
      @registers[x] = kk.to_u8
      next_code!
    when 0x7000
      @registers[x] = @registers[x] &+ kk
      next_code!
    when 0x8000
      case opcode & 0x000F
      when 0x0000
        @registers[x] = @registers[y]
      when 0x0001
        @registers[x] = @registers[x] | @registers[y]
      when 0x0002
        @registers[x] = @registers[x] & @registers[y]
      when 0x0003
        @registers[x] = @registers[x] ^ @registers[y]
      when 0x0004
        @registers[0xF] = (@registers[y] > UInt8::MAX - @registers[x]) ? 1_u8 : 0_u8
        @registers[x] = @registers[x] &+ @registers[y]
      when 0x0005
        borrow = @registers[x] < @registers[y] ? 1 : 0
        @registers[x] = @registers[x] &- @registers[y]
      when 0x0006
        @registers[0xF] = @registers[x] & 0x1
        @registers[x] = @registers[x] >> 1
      when 0x0007
        @registers[0xF] = @registers[y] < @registers[x] ? 1_u8 : 0_u8
        @registers[x] = @registers[y] &- @registers[x]
      when 0x000E
        @registers[0xF] = @registers[x] & 0x80
        @registers[x] = @registers[x] << 1
      end
      next_code!
    when 0x9000
      case opcode & 0x000F
      when 0x0000 
        @registers[x] != @registers[y] ? skip_next_code! : next_code!
      end
    when 0xA000
      @i = nnn
      next_code!
    when 0xB000
      @stack.push @pc
      @pc = nnn + @registers[0]
    when 0xC000
      @registers[x] = rand(0...256).to_u8 & kk
      next_code!
    when 0xD000
      collision = @video.draw_sprite(@memory[@i...(@i+n)], @registers[x], @registers[y])
      @registers[0xF] = (collision == true ? 1_u8 : 0_u8)
      next_code!
    when 0xE000
      case opcode & 0x00FF
      when 0x009E 
        @keyboard.pressed?(@registers[x]) ? skip_next_code! : next_code!
      when 0x00A1 
        @keyboard.pressed?(@registers[x]) ? next_code! : skip_next_code!
      end
    when 0xF000
      case opcode & 0x00FF
      when 0x0007 
        @registers[x] = @delay_timer
      when 0x000A
        return unless @keyboard.any_key_pressed?

        @registers[x] = @keyboard.pressed_key.not_nil!.to_u8
      when 0x0015 
        @delay_timer = @registers[x]
      when 0x0018
        @audio_timer = @registers[x]
      when 0x001E 
        @i += @registers[x]
      when 0x0029 
        @i = char_font_p(@memory[x])
      when 0x0033
        @memory[@i] = @registers[x] // 100
        @memory[@i + 1] = (@registers[x] // 10) % 10
        @memory[@i + 2] = @registers[x] % 10
      when 0x0055
        @registers[0..x].each_with_index { |e, i| @memory[@i + i] = e }
      when 0x0065
        (0..x).each { |xi| @registers[xi] = @memory[@i + xi] }
      end
      next_code!
    else
      raise "cant decode #{(opcode & 0xF000).to_s(16)}"
    end
  end

  def timers_cycle : Nil
    @delay_timer -= 1 if @delay_timer > 0
    @audio_timer -= 1 if @audio_timer > 0
  end

  def cpu_cycle : Nil    
    opcode = read_opcode
    process_(opcode)

    @video.refresh
    @keyboard.poll
  end

  def read_opcode
    Vm::OpCode.new((@memory[@pc].to_u16 << 8) | @memory[@pc + 1])
  end

  def next_code!
    @pc += 2
  end

  def skip_next_code!
    @pc += 4
  end
end
