#!/usr/bin/wish8.5

# Necessary for this library:
namespace import ::tcl::mathop::*

### START LIBRARY CODE ##########################

namespace eval ::progressbar {}
namespace eval ::progressbar::img {}

### CONFIG: R/G/B values for progressbar colors ###
set ::progressbar::bg_top [list 220 218 213] ;# dcdad5
set ::progressbar::bg_btm [list 200 198 190] ;# dcdad5
set ::progressbar::bar_top [list 255 0 0]
set ::progressbar::bar_btm [list 190 0 0]

namespace eval ::progressbar {
	### START INTERFACE PROCS ###

	## Interface:
	  # ::progressbar::create        widget ?width? ?height?
	  # ::progressbar::setfraction   widget fraction ?denom?
	  # ::progressbar::goto          widget X Y
	  # ::progressbar::advance_down  widget
	  # ::progressbar::advance_right widget
	# All procs except "create" return the actual (rounded) fraction of progress.

	# dict like {widgetname {x 0 y 0 w 100 h 20}}
	set progressbars [dict create]


	## widget constructor ##
	proc create {widget {width 160} {height 20}} {
		variable progressbars

		set img [image create photo img::$widget \
			-width $width -height $height]
		ttk::label $widget -relief sunken -image $img
		
		# data structures for setting the bar
		dict set progressbars $widget [dict create x 0 y 0 w $width h $height]

		# initial (background) gradient
		progressbar_paint_bg $widget
	}

	## sets progress to a given fraction ##
	# (optionally, a denominator can be given, such that progress = fraction / denom)
	proc setfraction {widget fraction {denom 1}} {
		variable progressbars
		if {$denom!=1} {set fraction [expr {$fraction / double($denom)}]}
		if {$fraction>1} {error "fraction over unity"}
		dict with progressbars $widget {
			set newX [expr {$w*$fraction}]
			set newY [expr {int(($newX-entier($newX))*$h)}]
			set newX [expr {entier($newX)}]
			# Optimized variant for new progress location same as before
			if {$newX==$x && $newY==$y} {
				return [progressbar_return $x $y $w $h]
			}
			# Optimized variant for new progress location in the same pixel column
			if {$newX==$x && $newY>=$y} {
				for {set iy [+ $y 1]} {$iy<=$newY} {incr iy} {
					progressbar_paint_pixel $widget [+ $x 1] $iy $h
				}
				progressbar_update $widget
				set y $newY
				return [progressbar_return $x $y $w $h]
			}
		}
		# General variant
		return [goto $widget $newX $newY]
	}

	## sets progress to a given absolute value ##
	proc goto {widget X Y} {
		# X = number of completely painted columns (0 to width)
		# Y = number of painted pixels in the next column (0 to height-1)
		variable progressbars
		dict with progressbars $widget {}
		if {$X < 0 || $X > $w}  {error "X=$X out of range"}
		if {$Y < 0 || $Y >= $h} {error "Y=$Y out of range"}
		if {$X == $w && $Y > 0} {error "For the last X, Y=0 is required"}

		progressbar_paint_bg $widget
		# set state to X,Y
		dict with progressbars $widget {
			set x $X
			set y $Y
		}
		for {set yy 1} {$yy<=$h} {incr yy} {
			progressbar_paint_line $widget [expr $X+($yy<=$Y)] $yy $h
		}
		progressbar_update $widget
		return [progressbar_return $x $y $w $h]
	}

	## increments progress by one pixel ##
	proc advance_down {widget} {
		variable progressbars
		dict with progressbars $widget {
			if {$x==$w} {return 1}
			incr y
			progressbar_paint_pixel $widget [+ $x 1] $y $h
			if {$y==$h} {
				set y 0
				incr x
			}
		}
		progressbar_update $widget
		return [progressbar_return $x $y $w $h]
	}

	## increments progress by one vertical line ##
	proc advance_right {widget} {
		variable progressbars
		dict with progressbars $widget {
			if {$x==$w} {return 1}
			incr x
			set y 0
		}
		for {set iy 1} {$iy<=$h} {incr iy} {
			progressbar_paint_pixel $widget $x $iy $h
		}
		progressbar_update $widget
		return [progressbar_return $x $y $w $h]
	} 

	### END INTERFACE PROCS ###

	### Utility procs for internal use ###

	# merge two colors (lists of {R G B}), alpha = portion of colorB
	proc colormerge {colorA colorB alpha} {
		set mergedcolor [list "" "" ""]
		for {set i 0} {$i<3} {incr i} {
			lset mergedcolor $i [expr {int(
				(1-$alpha)*[lindex $colorA $i] + $alpha*[lindex $colorB $i]
			)}]
		}
		return [format "#%02x%02x%02x" {*}$mergedcolor]
	}

	# paint the progressbar background
	proc progressbar_paint_bg {widget} {
		variable progressbars
		set img img::$widget
		dict with progressbars $widget {
			set width $w
			set height $h
		}
		for {set y 1} {$y <= $height} {incr y} {
			set q [expr $y/$height.] ;# off-by-one problems ignored
			set rowcolor [colormerge $::progressbar::bg_top $::progressbar::bg_btm $q]
			$img put $rowcolor -to 0 [- $y 1] $width $y
		}
	}	

	# paint the progressbar foreground (one pixel)
	#  (the height parameter is only here for efficiency)
	proc progressbar_paint_pixel {widget x y height} {
		set img img::$widget
		set q [expr $y/$height.] ;# off-by-one problems ignored
		set rowcolor [colormerge $::progressbar::bar_top $::progressbar::bar_btm $q]
		$img put $rowcolor -to [- $x 1] [- $y 1] $x $y
	}
	# paint the progressbar foreground (one horizontal line from 0 to x)
	#  (the height parameter is only here for efficiency)
	proc progressbar_paint_line {widget x y height} {
		set img img::$widget
		set q [expr $y/$height.] ;# off-by-one problems ignored
		set rowcolor [colormerge $::progressbar::bar_top $::progressbar::bar_btm $q]
		$img put $rowcolor -to 0 [- $y 1] $x $y
	}
	proc progressbar_update {widget} {
		$widget configure -image img::$widget
	}
	# return the progress fraction at the end of an interface proc
	proc progressbar_return {x y w h} {
		if {$x==$w && $y==$h} {return 1}
		return [expr {($x*$h+$y)/double($w*$h)}]
	}
}

### END LIBRARY CODE ############################

### Demo

ttk::style theme use clam
pack [::progressbar::create .test] -padx 10 -pady 10 -side top

ttk::frame .retval
ttk::label .retval.descr -text "Return value:"
ttk::label .retval.value -textvariable pos -font TkFixedFont
pack .retval.descr -side left -padx 5
pack .retval.value -side left -padx 5 -expand true -fill x
pack .retval -side bottom -fill x

ttk::button .advancedown -text "Advance down" -command \
	{set pos [::progressbar::advance_down .test]}
ttk::button .advanceright -text "Advance right" -command \
	{set pos [::progressbar::advance_right .test]}
pack .advancedown .advanceright -side left -padx 1 -pady 1
pack [ttk::separator .sep -orient v] -side left -fill y -expand true -padx 1 -pady 4

ttk::button .goto -text "Go to:" -command {
	if {[string is double $gotopos]} {
		set pos [::progressbar::setfraction .test $gotopos]
	} else { set pos [::progressbar::goto .test {*}$gotopos]}
}
ttk::entry .gotopos -width 6 -font "Monospace 14" -textvariable gotopos
# If you enter two integers, then progressbar::goto will be called.
# If you enter one (possibly non-integer) number, progressbar::setfraction
# will be called.
set gotopos "0 0" ;

bind .gotopos <Return> {.goto invoke}
trace add variable gotopos write {apply {{args} {
	global gotopos
	if {[string is double $gotopos] || [regexp  {^[0-9]+\ +[0-9]+$} $gotopos]} {
		# enable the button
		.goto state !disabled
	} else {
		# disable the button
		.goto state disabled
	}
}}}
pack .goto .gotopos -side left -padx 1 -pady 1 -fill y

# Automated Demo

pack [ttk::button .autodemo -text "Start Demo" -command autodemo_start] \
	-side right -padx 1 -pady 1

proc autodemo_start {} {
	.autodemo configure -text "Stop Demo" -command autodemo_stop
	set res [progressbar::advance_down .test]
	if {$res==1} {
		progressbar::goto .test 0 0
	}
	tick
}
proc autodemo_stop {} {
	.autodemo configure -text "Start Demo" -command autodemo_start
	after cancel tick
}

proc tick {} {
	if [expr rand()]<0.1 {
		set res [progressbar::advance_right .test]
	} else {
		set res [progressbar::advance_down .test]
	}
	if {$res==1} {
		autodemo_stop
	} else {
		after [expr int(rand()*20+20)] tick
	}
}
