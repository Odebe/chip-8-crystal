require "benchmark"
require "sdl"

require "./vm.cr"

module Cryp8
  VERSION = "0.1.0"
end

SDL.init(SDL::Init::VIDEO)
at_exit { SDL.quit }

Signal::INT.trap do
  puts "CTRL-C handler here!"
  exit
end

# file = File.open("BC_test.ch8")
# file = File.open("src/test_opcode.ch8")
# file = File.open("src/TETRIS")
# file = File.open("src/GUESS")
file = File.open("src/BRIX")

int = Vm::Interpreter.new(file)

int.load_program!
int.run!
