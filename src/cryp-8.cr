require "benchmark"
require "sdl"


# require "ncurses"


# TODO: Write documentation for `Cryp::8`
module Cryp8
  VERSION = "0.1.0"

  # TODO: Put your code here
end

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

  def to_s
    @values.map { |e| e.to_s }.join(", ")
  end
end

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

module Vm::Video::Interface
  abstract def puts(msg : String) : Nil
  abstract def refresh: Nil
  abstract def start: Nil
  abstract def stop: Nil
end

# class Vm::Video::Memory
#   # include Vm::Video::Interface

#   @pixel_h : UInt8
#   @pixel_w : UInt8

#   def initialize
#     # @actions = [] of { x: UInt8, y: UInt8 }
#     @memory = Array(UInt64).new(32, 0) # handles 64hx32w
    
#     @pixel_h = 10.to_u8 # (width / 32).to_i32
#     @pixel_w = 10.to_u8 # (hidth / 64).to_i32
#   end

#   def puts(msg : String) : Nil
#   end

#   def log_sprite(sprite : Array(UInt8))
#     sprite.map { |e| e.to_s(2) }.join("\n")
#   end

#   # rewrite with pointers on memory MAXIMUM UNSAFE!!111
#   def draw_sprite(sprite_bytes : Array(UInt8), x, y)
#     yield "\n#{log_sprite(sprite_bytes)}"

#     collision = false

#     sprite_bytes.each_with_index do |sprite_pixel, sprite_line_index|
#       line_num = y + sprite_line_index
#       display_line = @memory[line_num]

#       (0..8).each do |xi|
#         next if (sprite_pixel & (0x80 >> xi)) == 0

#         display_bit_p = (1.to_u64 << (63 - (x + xi)))
#         collision = true if (display_line & display_bit_p) == 1
#         @memory[line_num] ^= 1 #display_bit_p
#       end
#     end

#     collision
#   end

#   def refresh: Nil
#     @renderer.draw_color = SDL::Color[255, 255, 255, 255]
#     @renderer.clear

#     @renderer.draw_color = SDL::Color[0, 0, 0, 255]
#     @memory.each_with_index do |line, line_i|
#       (0..64).each do |pix_i|
#         pix_value = line & (1.to_u64 << (63 - pix_i))

#         @renderer.draw_color = 
#           if pix_value == 1
#             SDL::Color[0, 0, 0, 255]
#             SDL::Color[255, 255, 255, 255]

#           else
#             SDL::Color[255, 255, 255, 255]
#           end

#         @renderer.fill_rect(pix_i * @pixel_w, line_i * @pixel_h, @pixel_w.to_i32, @pixel_h.to_i32)
#       end
#     end

#     @renderer.present
#   end

#   def start: Nil
#   end

#   def stop: Nil
#     # SDL.quit
#   end
# end

SDL.init(SDL::Init::VIDEO)
at_exit { SDL.quit }

class Vm::Interpreter
  @i : UInt16
  @start_p : UInt16
  @pc : UInt16
  @pixel_h : UInt8
  @pixel_w : UInt8


  def initialize(@file : File)
    @stack = Vm::Stack(UInt16).new
    @registers = Vm::Registers(UInt8).new
    @memory = Vm::Memory.new
    
    @window = SDL::Window.new("Cryps-8!", 640, 320)
    @renderer = SDL::Renderer.new(@window)
    @video_memory = Array(UInt64).new(32, 0) # handles 64hx32w
 
    # @pixel_h = 10.to_u8 # (width / 32).to_i32
    # @pixel_w = 10.to_u8 # (hidth / 64).to_i32

    @pixel_h = (@window.height / 32).to_u8
    @pixel_w = (@window.width / 64).to_u8

    @i = 0.to_u16
    @start_p = 0x200.to_u16
    @pc = @start_p.to_u16
  end

  def running?
    (@pc - @start_p) < @file.size
  end

  def load_program!: Nil
    @file.rewind
    (0...@file.size).each do |i|
      @memory[@start_p + i] = @file.read_bytes(UInt8, IO::ByteFormat::BigEndian)
    end
  end

  def run! : Nil
    cycle do |opcode|
      case opcode & 0xF000
      when 0x0000
        case opcode & 0x00FF
        when 0x00E0
          log "Clears the screen."
          @pc += 2
        when 0x00EE
          v = @stack.pop
          log "Returns from a subroutine to #{v.to_s(16)} (#{(v+2).to_s(16)})."
          @pc = (v + 2)
        end
      when 0x1000
        addr = opcode & 0x0FFF
        log "Jumps to address #{addr.to_s(16)}."
        @pc = addr
      when 0x2000
        addr = opcode & 0x0FFF
        @stack.push @pc
        log "Calls subroutine at #{addr.to_s(16)}."
        @pc = addr + 2
      when 0x3000
        x = (opcode & 0x0F00) >> 8
        nn = opcode & 0x00FF
        log "Skips the next instruction if V#{x} equals #{nn}."
        s = @registers[x] == nn ? 4 : 2
        @pc += s
      when 0x4000
        x = (opcode & 0x0F00) >> 8
        nn = opcode & 0x00FF
        log "Skips the next instruction if V#{x} doesn't equal #{nn}. "
        s = @registers[x] != nn ? 4 : 2
        @pc += s
      when 0x5000 
        case opcode & 0x000F
        when 0x0000
          x = (opcode & 0x0F00) >> 8
          y = (opcode & 0x00F0) >> 4
          log "Skips the next instruction if V#{x} equals V#{y}."
          s = @registers[x] == @registers[x] ? 4 : 2
          @pc += s
        end
      when 0x6000
        x = (opcode & 0x0F00) >> 8
        nn = opcode & 0x00FF
        log "Sets V#{x} to #{nn}."
        @registers[x] = nn.to_u8
        @pc += 2
      when 0x7000
        x = (opcode & 0x0F00) >> 8
        nn = opcode & 0x00FF
        log "Adds #{nn} to V#{x}. (Carry flag is not changed)"
        @registers[x] = (@registers[x] | nn)
        @pc += 2
      when 0x8000
        x = (opcode & 0x0F00) >> 8
        y = (opcode & 0x00F0) >> 4
        case opcode & 0x000F
        when 0x0000
          log "Sets V#{x} to the value of V#{y}."
          @registers[x] = @registers[y]
        when 0x0001
          log "Sets V#{x} to V#{x} or V#{y}. (Bitwise OR operation)"
          @registers[x] = @registers[x] | @registers[y]
        when 0x0002
          log "Sets V#{x} to V#{x} and V#{y}. (Bitwise AND operation)"
          @registers[x] = @registers[x] & @registers[y]
        when 0x0003
          log "Sets V#{x} to V#{x} xor V#{y}."
          @registers[x] = @registers[x] ^ @registers[y]
        when 0x0004
          log "Adds V#{y} to V#{x}. VF is set to 1 when there's a carry, and to 0 when there isn't."
          borrow = (@registers[y] > (0xFF - @registers[x])) ? 1 : 0
          @registers[0xF] = borrow.to_u8
          @registers[x] = @registers[x] | @registers[y]
        when 0x0005
          log "V#{y} is subtracted from V#{x}. VF is set to 0 when there's a borrow, and 1 when there isn't."
          result = @registers[x] ^ @registers[y]
          borrow = result > @registers[x] ? 1 : 0
          @registers[0xF] = borrow.to_u8
          @registers[x] = result
        when 0x0006
          log "Stores the least significant bit of V#{x} in VF and then shifts V#{x} to the right by 1."
          @registers[0xF] = @registers[x] & 0x1
          @registers[x] = @registers[x] >> 1
        when 0x0007
          log "Sets V#{x} to V#{y} minus V#{x}. VF is set to 0 when there's a borrow, and 1 when there isn't."
          result = @registers[y] ^ @registers[x]
          borrow = result > @registers[y] ? 1 : 0
          @registers[0xF] = borrow.to_u8
          @registers[x] = result
        when 0x000E
          log "Stores the most significant bit of V#{x} in VF and then shifts V#{x} to the left by 1."
          @registers[0xF] = @registers[x] & 0x80
          @registers[x] = @registers[x] << 1
        end
        @pc += 2
      when 0x9000
        case opcode & 0x000F
        when 0x0000
          x = (opcode & 0x0F00) >> 8
          y = (opcode & 0x00F0) >> 4
          log "Skips the next instruction if V#{x} doesn't equal V#{y}. "
          s = @registers[x] != @registers[7] ? 4 : 2
          @pc += 2
        end
      when 0xA000
        addr = opcode & 0x0FFF
        log "Sets I to the address #{addr}."
        @i = addr
        @pc += 2
      when 0xB000
        nnn = opcode & 0x0FFF
        log "Jumps to the address #{nnn} plus V0."
        @stack.push @pc
        @pc = nnn + @registers[0]
      when 0xC000
        x = (opcode & 0x0F00) >> 8
        nn = opcode & 0x00FF
        log "Sets V#{x} to the result of a bitwise and operation on a random number (Typically: 0 to 255) and #{nn}."
        @registers[x] = rand(0...256).to_u8 & nn
        @pc += 2
      when 0xD000
        x = (opcode & 0x0F00) >> 8
        y = (opcode & 0x00F0) >> 4
        n = opcode & 0x000F
        log "Draws a sprite at coordinate (V#{x}, V#{y}) that has a width of 8 pixels and a height of #{n} pixels. "
        sprite_bytes = @memory[@i..(@i+n)]
        collision = draw_sprite(sprite_bytes, x, y)
        @registers[0xF] = 1 if collision
        @pc += 2
      when 0xE000
        x = (opcode & 0x0F00) >> 8
        case opcode & 0x00FF
        when 0x009E
          log "Skips the next instruction if the key stored in V#{x} is pressed."
        when 0x00A1
          log "Skips the next instruction if the key stored in V#{x} isn't pressed. "
        end
        @pc += 2
      when 0xF000
        x = (opcode & 0x0F00) >> 8
        case opcode & 0x00FF
        when 0x0007
          log "Sets V#{x} to the value of the delay timer."
        when 0x000A
          log "A key press is awaited, and then stored in V#{x}. (Blocking Operation. All instruction halted until next key event)"
        when 0x0015
          log "Sets the delay timer to V#{x}."
        when 0x0018
          log "Sets the sound timer to V#{x}."
        when 0x001E
          log "Adds V#{x} to I. VF is not affected."
          @i += x
        when 0x0029
          log "Sets I to the location of the sprite for the character in V#{x}. Characters 0-F (in hexadecimal) are represented by a 4x5 font."
        when 0x0033
          log "Stores the binary-coded decimal representation of V#{x}"
        when 0x0055
          log "Stores V0 to V#{x} (including V#{x}) in memory starting at address I."
        when 0x0065
          log "Fills V0 to V#{x} (including V#{x}) with values from memory starting at address I."
        end
        @pc += 2
      else
        raise "cant decode #{(opcode & 0xF000).to_s(16)}"
      end
    end
  end

  def log(str)
    # @video.puts "[#{@pc.to_s(16)}] [Reg: #{@registers.to_s}] #{str.to_s}"
    puts "[#{@pc.to_s(16)}] [Reg: #{@registers.to_s}] #{str.to_s}"
  end

  def cycle : Nil
    cycle_per_sec = 10
    cycle_nanoseconds = (1_000_000_000/cycle_per_sec).to_i32
    cycle_time = Time::Span.new(nanoseconds: cycle_nanoseconds)

    while running?
      realtime = Benchmark.realtime do
        yield opcode_at(@pc)
      end

      sleep(cycle_time - realtime)

      refresh
      # raise "meh" if @pc == 0x30e
      # if @pc == 0x30e
      #   @video_memory.each do |vl|
      #     puts vl.to_s(2)
      #   end
      #   sleep
      # end
    end
  end

  def opcode_at(i)
    code_value = (@memory[i].to_u16 << 8) | @memory[i + 1]
    Vm::OpCode.new(code_value)
  end

  def draw_sprite(sprite_bytes : Array(UInt8), x, y)
    collision = false

    sprite_bytes.each_with_index do |sprite_pixel, sprite_line_index|
      line_num = y + sprite_line_index
      display_line = @video_memory[line_num]

      (0..8).each do |xi|
        # next if (sprite_pixel & (0x80 >> xi)) == 0

        display_bit_p = (1.to_u64 << (63 - (x + xi)))
        collision = true if (display_line & display_bit_p) == 1
        @video_memory[line_num] ^= display_bit_p
      end
    end

    collision
  end

  module Colors
    GRAY = SDL::Color[175, 175, 175, 255]
    WHITE = SDL::Color[255, 255, 255, 255] 
    BLACK = SDL::Color[0, 0, 0, 255]
  end

  def refresh: Nil
    @renderer.draw_color = Colors::GRAY
    @renderer.clear

    @video_memory.each_with_index do |line, line_i|
      (0..64).each do |pix_i|
        offset = 63 - pix_i
        pix_value = (line & (1.to_u64 << offset)) >> offset
        @renderer.draw_color = pix_value == 1 ? Colors::BLACK : Colors::WHITE 
        @renderer.fill_rect(pix_i * @pixel_w, line_i * @pixel_h, @pixel_w.to_i32 - 1, @pixel_h.to_i32 - 1)
      end
    end

    @renderer.present
  end
end

Signal::INT.trap do
  puts "CTRL-C handler here!"
  exit
end

# file = File.open("BC_test.ch8")
# file = File.open("src/test_opcode.ch8")
# file = File.open("src/TETRIS")
file = File.open("src/GUESS")

int = Vm::Interpreter.new(file)

int.load_program!
int.run!
