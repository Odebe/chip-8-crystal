
class Vm::Interpreter
  @i : UInt16
  @start_p : UInt16
  @font_start_p : UInt16
  @pc : UInt16
  @delay_timer : UInt8

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
        case opcode & 0x000F
        when 0x0000
          log "Clears the screen."
          @video.clear!
          @pc += 2
        when 0x000E
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
        @pc = addr
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
          s = @registers[x] == @registers[y] ? 4 : 2
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
        @registers[x] = @registers[x] &+ nn
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
          borrow = (@registers[y] > UInt8::MAX - @registers[x]) ? 1_u8 : 0_u8
          @registers[0xF] = borrow
          @registers[x] = @registers[x] &+ @registers[y]
        when 0x0005
          log "V#{y} is subtracted from V#{x}. VF is set to 0 when there's a borrow, and 1 when there isn't."
          borrow = @registers[x] < @registers[y] ? 1 : 0
          @registers[x] = @registers[x] &- @registers[y]
        when 0x0006
          log "Stores the least significant bit of V#{x} in VF and then shifts V#{x} to the right by 1."
          @registers[0xF] = @registers[x] & 0x1
          @registers[x] = @registers[x] >> 1
        when 0x0007
          log "Sets V#{x} to V#{y} minus V#{x}. VF is set to 0 when there's a borrow, and 1 when there isn't."
          borrow = @registers[y] < @registers[x] ? 1_u8 : 0_u8
          @registers[0xF] = borrow
          @registers[x] = @registers[y] &- @registers[x]
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
          s = @registers[x] != @registers[y] ? 4 : 2
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
        collision = @video.draw_sprite(@memory[@i...(@i+n)], @registers[x], @registers[y])
        @registers[0xF] = (collision == true ? 1_u8 : 0_u8)
        @pc += 2
      when 0xE000
        x = (opcode & 0x0F00) >> 8
        case opcode & 0x00FF
        when 0x009E
          log "Skips the next instruction if the key stored in V#{x} is pressed."
          key = @registers[x]
          s = @keyboard.pressed?(key) ? 4 : 2
          @pc += s
        when 0x00A1
          log "Skips the next instruction if the key stored in V#{x} isn't pressed. "
          key = @registers[x]
          s = @keyboard.pressed?(key) ? 2 : 4
          @pc += s
        end
      when 0xF000
        x = (opcode & 0x0F00) >> 8
        case opcode & 0x00FF
        when 0x0007
          log "Sets V#{x} to the value of the delay timer."
          @registers[x] = @delay_timer
        when 0x000A
          log "A key press is awaited, and then stored in V#{x}. (Blocking Operation. All instruction halted until next key event)"
          return unless @keyboard.any_key_pressed?

          @registers[x] = @keyboard.pressed_key.not_nil!.to_u8
        when 0x0015
          log "Sets the delay timer to V#{x}."
          @delay_timer = @registers[x]
        when 0x0018
          log "Sets the sound timer to V#{x}."
        when 0x001E
          log "Adds V#{x} to I. VF is not affected."
          @i += @registers[x]
        when 0x0029
          log "Sets I to the location of the sprite for the character in V#{x} {#{@memory[x]}}. Characters 0-F (in hexadecimal) are represented by a 4x5 font."
          @i = char_font_p(@memory[x])
        when 0x0033
          # Store BCD representation of Vx in memory location starting at location I.
          log "Stores the binary-coded decimal representation of V#{x}"
          @memory[@i] = @registers[x] // 100
          @memory[@i + 1] = (@registers[x] // 10) % 10
          @memory[@i + 2] = @registers[x] % 10
        when 0x0055
          log "Stores V0 to V#{x} (including V#{x}) in memory starting at address I."
          @registers[0..x].each_with_index do |e, i|
            @memory[@i + i] = e
          end
        when 0x0065
          log "Fills V0 to V#{x} (including V#{x}) with values from memory starting at address I."
          (0..x).each do |xi|
            @registers[xi] = @memory[@i + xi]
          end
        end
        @pc += 2
      else
        raise "cant decode #{(opcode & 0xF000).to_s(16)}"
      end
    end
  end

  def log(str)
    # puts "[#{@pc.to_s(16)}] [I: #{@i}] [T: #{@delay_timer}][Reg: #{@registers.to_s}] #{str.to_s}"
  end

  def cycle : Nil
    cycle_per_sec = 12000
    cycle_nanoseconds = (1_000_000_000/cycle_per_sec).to_i32
    cycle_time = Time::Span.new(nanoseconds: cycle_nanoseconds)

    while running?
      realtime = Benchmark.realtime do
        yield opcode_at(@pc)
        @video.refresh
        @delay_timer -= 1 if @delay_timer > 0
        @keyboard.poll
      end
      sleep(cycle_time - realtime)
    end
  end

  def opcode_at(i)
    code_value = (@memory[i].to_u16 << 8) | @memory[i + 1]
    Vm::OpCode.new(code_value)
  end
end
