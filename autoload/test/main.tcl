#!/usr/bin/tclsh8.5

# Normal way of enabling tclIndex
lappend auto_path [file normalize [file dirname [info script]]]

# Fast way of enabling tclIndex
if {"--slow" ni $argv} {
  # this variable is used in the tclIndex script and must refer to the
  # directory in which the tclIndex is placed.
  set dir [file dirname [info script]]
  source [file join $dir tclIndex]
}

# First command: Say hello
puts "First auto-loaded procedure: helloworld"
puts [time {helloworld}]
puts ""

# Other commands
hello User
puts ""
Nspace::external
puts ""
Nspace::internal x y
puts ""
Nspace::private::real-internal x y z
puts ""
goodbye User
