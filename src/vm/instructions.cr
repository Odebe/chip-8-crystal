module Vm::Instructions
  module OpcodeMacros
    def cls
      puts "CLS"  
    end

   def ret
      puts "RET"
   end

    def sys(nnn)
      puts "SYS #{nnn}"
    end
  end

  extend self
  extend Vm::Instructions::OpcodeMacros

  macro unfold_case(opcodes_arr)
    kk = opcode & 0x00FF
    nnn = opcode & 0x0FFF
    
    h = (opcode & 0xF000) >> 12
    x = (opcode & 0x0F00) >> 8
    y = (opcode & 0x00F0) >> 4
    n = opcode & 0x000F
    
    puts opcode
    {% begin %}
    case {h, x, y, n}
      {% for opcode_spec in opcodes_arr %}
    when {{ opcode_spec[0] }}
      log  "#{{{ opcode_spec[1]  }}} #{{{ opcode_spec[2].join(", ") }}}"
      {{opcode_spec[1].downcase.id}}({{ opcode_spec[2].join(", ").id }})
      {% end %} 
    else #  {_, _, _, _}
      puts opcode.to_s(16)
    end
    {% end %}
  end

  def _process(opcode)
    unfold_case [
      { {0,0,0xE,0}, "CLS", [""]},
      { {0,0, 0xE, 0xE}, "RET", [""]},
      { {0, _, _, _}, "SYS", ["nnn"]}
    ]
  end
  
  def log(str)
    puts str
  end
end

