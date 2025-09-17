#!/usr/bin/env ruby
require 'digest'

if ARGV.length != 1
  STDERR.puts "Usage: #{$0} <file>"
  exit 1
end

file = ARGV[0]
unless File.exist?(file)
  STDERR.puts "File not found: #{file}"
  exit 1
end

digest = Digest::MD5.file(file).hexdigest
puts "#{digest}  #{file}"
