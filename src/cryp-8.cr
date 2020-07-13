require "benchmark"
require "sdl"

require "./vm.cr"

module Cryp8
  VERSION = "0.1.0"
end

Signal::INT.trap do
  puts "CTRL-C handler here!"
  exit
end

# file = File.open("roms/BC_test.ch8")
# file = File.open("roms/test_opcode.ch8")
# file = File.open("roms/TETRIS")
# file = File.open("roms/GUESS")
file = File.open("roms/BRIX")

int = Vm::Interpreter.new(file)

int.load_program!
int.run!
