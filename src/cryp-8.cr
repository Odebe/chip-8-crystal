require "sdl"
require "option_parser"
require "./vm.cr"

module Cryp8
  VERSION = "0.2.0"
end

rom = "./roms/test_opcode.ch8"
debug = false

OptionParser.parse do |parser|
  parser.banner = "Usage: cryp-8 [arguments]"
  parser.on("-d", "--debug", "Enable debug logs") { debug = true }
  parser.on("-r ROM_PATH", "--rom=ROM_PATH", "Path to rom file") do |rom_path|
    if rom_path.strip.blank? || !File.exists?(rom_path)
      puts "Invalid rom path. '#{rom_path}'"
      exit
    end
    rom = rom_path
   end
  parser.on("-h", "--help", "Show this help") { puts parser; exit }
end

Signal::INT.trap do
  puts "CTRL-C handler here!"
  exit
end

file = File.open(rom)

int = Vm::Interpreter.new(file, debug: debug)

int.load_program!
int.run!
