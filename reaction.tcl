#!/usr/bin/wish8.5
ttk::style theme use clam

pack [ttk::button .button -text "\nLoading...\n"]
pack [ttk::label .message -textvariable message]
after idle reset

proc reset {} {
	after cancel trip
	.button configure -text "\nStart\n" -command start
}

proc start {} {
	after [expr int(rand()*5000)] trip
	.button configure -text "\nWait\n" -command fail
	set ::message ""
}

proc fail {} {
	set ::message "You pressed too\nearly, you cheater!!!"
	reset
}

proc trip {} {
	.button configure -text "\nClick me\n" -command success
	set ::triptime [clock milliseconds]
}

proc success {} {
	set time [expr [clock milliseconds]-$::triptime]
	if {[info exists ::mintime]} {
		set ::mintime [expr min($::mintime,$time)]
	} else {
		set ::mintime $time
	}
	set ::message "Your reaction time:\n$time milliseconds.\nBest time today:\n$::mintime milliseconds."
	reset
}
