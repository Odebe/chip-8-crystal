class Vm::Keyboard
  KEYMAP = {
    LibSDL::Keycode::KEY_1 => 0x1,
    LibSDL::Keycode::KEY_2 => 0x2,
    LibSDL::Keycode::KEY_3 => 0x3,
    LibSDL::Keycode::KEY_4 => 0xC,

    LibSDL::Keycode::Q => 0x4,
    LibSDL::Keycode::W => 0x5,
    LibSDL::Keycode::E => 0x6,
    LibSDL::Keycode::R => 0xD,

    LibSDL::Keycode::A => 0x7,
    LibSDL::Keycode::S => 0x8,
    LibSDL::Keycode::D => 0x9,
    LibSDL::Keycode::F => 0xE,

    LibSDL::Keycode::Z => 0xA,
    LibSDL::Keycode::X => 0x0,
    LibSDL::Keycode::C => 0xB,
    LibSDL::Keycode::V => 0xF
  }

  def initialize
    # TODO: Переписать на UInt16-число
    @keyboard = Array(UInt8).new(16, 0)
  end

  def pressed_key
    @keyboard.index(1)
  end

  def key(n : UInt8)
    @keyboard[n]
  end

  def pressed?(n : UInt8)
    key(n) == 1
  end

  def any_key_pressed?
    @keyboard.any?(1)
  end

  def poll
    case event = SDL::Event.poll
    when SDL::Event::Quit
      exit
    when SDL::Event::Keyboard
      exit if event.sym.escape?

      if KEYMAP[event.sym]?
        key = KEYMAP[event.sym]
        @keyboard[key] = event.keydown? ? 1_u8 : 0_u8
      end
    end
  end
end
