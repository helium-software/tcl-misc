#!/usr/bin/wish8.5

proc polygonal {args} {
	set pi [expr { 2*acos(0) }]
	# default setup
	set corners 5  ;# draw pentagons
	set count 4 ;# draw 4 of them
	set distance 10 ;# distance between corner "dots" in radial direction (inside-out)
	set radius 2 ;# radius of "dots"
	set colors [list #f00 #f90 #dd0 #0c0 #00f #f0f] ;# color of "dots", cycles through when starting the next polygon
	set center {0 0} ;# center point, list of {x y}
	set canvas .c ;# canvas widget to paint figure in
	set tag "" ;# tag to give to the "dots"

	# override default setup with the supplied arguments
	set available_options [list -corners -count -distance -radius -colors -center -canvas -tag]
	foreach {option value} $args {
		if {$option ni $available_options} {
			error "bad option \"$option\": must be [join [lrange $available_options 0 end-1] {, }], or [lindex $available_options end]"
		}
		# set corresponding variable, discarding the leading "-"
		set [string range $option 1 end] $value
	}

	# draw the polygons
	lassign $center centerX centerY

	for {set iter 0} {$iter<$count} {incr iter} {
		# draw next polygon
		set Radius [expr { $iter*$distance }]
		set color [lindex $colors [expr { $iter % [llength $colors] }]]
		for {set angle 0} {$angle < 2*$pi} {set angle [expr { $angle+2*$pi/$corners }]} {
			# draw next edge
			set corner1X [expr { $centerX + $Radius*sin($angle-$pi/$corners) }]
			set corner1Y [expr { $centerY + $Radius*cos($angle-$pi/$corners) }]
			set corner2X [expr { $centerX + $Radius*sin($angle+$pi/$corners) }]
			set corner2Y [expr { $centerY + $Radius*cos($angle+$pi/$corners) }]
			for {set dot 0} {$dot<max($iter,1)} {incr dot} {
				# draw next dot
				set t [expr { 1.0*$dot/max($iter,1) }] ;# parameter along line corner1..corner2
				set dotX [expr { $corner1X*(1-$t) + $corner2X*$t }]
				set dotY [expr { $corner1Y*(1-$t) + $corner2Y*$t }]
				set top [expr { $dotY - $radius }]
				set bottom [expr { $dotY + $radius }]
				set left [expr { $dotX - $radius }]
				set right [expr { $dotX + $radius }]
				$canvas create oval $left $top $right $bottom -fill $color -outline "" -tags $tag
				# first iteration requires only one dot to be drawn
				if {$iter==0} break
			}
			if {$iter==0} break
		}
	}
}

## Testbed code
ttk::style theme use clam
. configure -bg "#dcdad5"
pack [ttk::panedwindow .pw] -fill both -expand true
.pw add [ttk::frame .pw.f1] -weight 1
pack [ttk::frame .cf -relief sunken -border 1] -in .pw.f1 -fill both -expand true -padx 2 -pady 2
pack [canvas .c -background "#eeebe7"] -in .cf -fill both -expand true
# Move the canvas with mouse dragging
bind .c <ButtonPress-1> {.c scan mark %x %y; .c configure -cursor "fleur"}
bind .c <B1-Motion> {.c scan dragto %x %y 1}
bind .c <ButtonRelease-1> {.c configure -cursor ""}
# Double-click centers the view
proc canvas_center {} {
	.c configure -xscrollincrement [expr {[winfo width .c]/2}] -yscrollincrement [expr {[winfo height .c]/2}]
	.c xview moveto 0.5; .c xview scroll -1 units
	.c yview moveto 0.5; .c yview scroll -1 units
	.c configure -xscrollincrement 0 -yscrollincrement 0
}
bind .c <Double-1> {canvas_center}
# Text entry
.pw add [ttk::frame .pw.f2] -weight 0
pack [ttk::frame .tf -relief sunken -border 1] -in .pw.f2 -fill both -expand true -padx 2 -pady 2
pack [text .t -background "#eeebe7" -border 0 -highlightthick 0 -width 1 -height 2] -in .tf -fill both -expand true
.t insert end {polygonal -count 10 -corners 5}
# Execute hint
ttk::label .hint -text "Press Control-R to execute" -font TkSmallCaptionFont
proc hint {hint} {
	.hint configure -text $hint
	place .hint -in .c -anchor se -relx 1 -rely 1
}
proc modified {} {
	if {[.t edit modified]} {
		hint "Press Control-R to execute"
	} else {
		place forget .hint
	}
}
bind .t <<Modified>> modified
# Execute function
proc execute {} {
	.t edit modified 0
	.c delete all
	if {[catch [.t get 1.0 end] result]} {
		hint $result
	}
	canvas_center
}
bind all <Control-r> execute
# hack for enabling canvas_center to work properly; failure is otherwise caused by -weight @ panedwindow
after 10 {update; execute}
