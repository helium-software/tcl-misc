#!/usr/bin/tclsh
# Main program of Package / Module tests

# 1. Classical Package retrieval #########################

# necessary to let Tcl find the pkgIndex.tcl
lappend auto_path [file normalize [file dirname [info script]]]
puts "\$auto_path = \{\n  [join $auto_path "\n  "]\n\}"

package require testpkg
testpkg_test

package require testpkgN
testpkgN::method   this is testpkgN::member
puts [testpkgN::method]
puts ""

# 2. Tcl Modules system ##################################

# necessary to let Tcl find *.tm
tcl::tm::path add [file normalize [file join \
  [file dirname [info script]] Modules]]
puts "\[tcl::tm::path list\] = \{\n  [join [tcl::tm::path list] "\n  "]\n\}"

package require testmod
testmod_test

package require testmodN
testmodN::method   this is testmodN::member
puts [testmodN::method]
