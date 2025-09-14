#!/usr/bin/env ruby
require 'base64'
cmd = ARGV[0]
data = STDIN.read
if cmd == 'encode'
  print Base64.strict_encode64(data)
elsif cmd == 'decode'
  begin
    print Base64.strict_decode64(data)
  rescue
    STDERR.puts "Bad base64"
    exit 2
  end
else
  STDERR.puts "Usage: b64helper.rb encode|decode"
  exit 1
end
