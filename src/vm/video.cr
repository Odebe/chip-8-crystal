SDL.init(SDL::Init::VIDEO)
at_exit { SDL.quit }

class Vm::Video
  module Colors
    GRAY = SDL::Color[175, 175, 175, 255]
    WHITE = SDL::Color[255, 255, 255, 255]
    BLACK = SDL::Color[0, 0, 0, 255]
  end

  @pixel_h : UInt8
  @pixel_w : UInt8

  def initialize
    @window = SDL::Window.new("Cryps-8!", 640, 320)
    @renderer = SDL::Renderer.new(@window)
    @video_memory = Array(UInt64).new(32, 0) # handles 64hx32w
    @pixel_h = (@window.height / 32).to_u8
    @pixel_w = (@window.width / 64).to_u8
    @draw_flag = true
  end

  def clear!
    @video_memory = Array(UInt64).new(@video_memory.size, 0)
  end

  def size
    @video_memory.size
  end

  def draw_sprite(sprite_bytes : Array(UInt8), x, y)
    @draw_flag = true
    collision = false

    sprite_bytes.each_with_index do |sprite_pixel, sprite_line_index|
      line_num = y + sprite_line_index
      (0...8).each do |xi|
        next if (sprite_pixel & (0x80 >> xi)) == 0

        offset = 63 - x - xi
        display_bit_p = 1_u64 << offset
        collision = true if (@video_memory[line_num] & display_bit_p) > 0

        @video_memory[line_num] ^= display_bit_p
      end
    end

    collision
  end

  def refresh: Nil
    return unless @draw_flag

    @draw_flag = false
    @renderer.draw_color = Colors::GRAY
    @renderer.clear

    # @video_memory = Array(UInt64).new(@video_memory.size) { rand(0.to_u64...UInt64::MAX) }

    @video_memory.each_with_index do |line, line_i|
      (0...64).each do |pix_i|
        offset = 63 - pix_i
        pix_value = (line & (1.to_u64 << offset)) >> offset
        @renderer.draw_color = pix_value == 1 ? Colors::BLACK : Colors::WHITE
        @renderer.fill_rect(pix_i * @pixel_w, line_i * @pixel_h, @pixel_w.to_i32, @pixel_h.to_i32)
      end
    end

    @renderer.present
  end
end
