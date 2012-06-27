#!/usr/bin/wish8.5

# Prevent "obscure" uses of 'set'
proc get {arg} {uplevel set $arg}

ttk::style theme use clam
ttk::style configure TButton -width {} -padding {1 0}
ttk::style configure TCombobox -padding 1
ttk::style configure TFrame -relief raised -darkcolor [get ttk::theme::clam::colors(-lighter)]
. configure -bg #dcdad5

# Set up GUI
wm minsize . 614 200

canvas .canvas -bg white -width 1 -height 1 -closeenough 0 -cursor left_ptr
pack .canvas -fill both -expand true
wm geometry . 800x500

ttk::button .delete -text "Delete all" -takefocus 0 -command button.delall
ttk::button .insert -text "Insert point" -takefocus 0 -command button.insert

proc placeRightTo {ref w {pad 4}} {
   scan [winfo geometry $ref] %dx%d+%d  width trash x
   place $w -x [expr {$width+$x+$pad}]
}
proc placeLeftTo {ref w {pad 4}} {
   scan [winfo geometry $ref] %dx%d+%d  trash trash x
   set ww [winfo width .]
   if {$x < 0} return
   place $w -x [expr {$x-$pad-$ww}]
}

place .insert -in .canvas -relx 1 -rely 1 -anch se -x -3 -y -3
place .delete -in .canvas -relx 1 -rely 1 -anch se       -y -3
   bind .insert <Configure> {placeLeftTo .insert .delete}

# Set up settings controls

ttk::combobox .algorithm -textvariable settings(algorithm) -state readonly -width 11 -takefocus 0 \
     -values {Polygon "Tk Smooth" Trigonometric "Trig. Dots"}
place .algorithm -in .canvas -rely 1 -anch sw -x 3 -y -3

ttk::frame .closepathf -padding 1
ttk::checkbutton .closepath -text "Close path" -variable settings(closepath) -takefocus 0 -padding 1
pack .closepath -in .closepathf
place .closepathf -in .canvas -rely 1 -anch sw -y -3
   bind .algorithm <Configure> {placeRightTo .algorithm .closepathf}

ttk::frame .factorf -padding 1
spinbox .factor -from 2 -to 1024 -incr 1 -textvariable settings(factor) -width 4 \
   -buttonuprelief flat -buttondownrelief flat -relief flat -border 0 
pack [ttk::label .factorf.l -text "samples / segment"] -side right
pack .factor -in .factorf -side left
place .factorf -in .canvas -rely 1 -anch sw -y -3
   bind .closepathf <Configure> {placeRightTo .closepathf .factorf}

ttk::frame .offsetf -padding 1
spinbox .offset -from -10 -to 10 -incr 1 -textvariable settings(offset) -width 3 \
   -buttonuprelief flat -buttondownrelief flat -relief flat -border 0
pack [ttk::label .offsetf.l -text "Pad offset:"] -side left
pack .offset -in .offsetf -side left
place .offsetf -in .canvas -rely 1 -anch sw -x 0 -y -3
  bind .factorf <Configure> {placeRightTo .factorf .offsetf}

### DEFAULT SETTINGS
array set settings {algorithm Polygon closepath no factor 32 offset 1}

trace add variable settings write settings.update
proc settings.update {args} {interpol.redraw}

after idle event generate .algorithm <<ComboboxSelected>>

bind .algorithm <<ComboboxSelected>> {
   .algorithm selection clear; focus .

   switch [get settings(algorithm)] {
      "Polygon" - "Tk Smooth" {
          # Hide additional controls
          place .factorf -y -10000 -rely 0
          place .offsetf -y -10000 -rely 0
      }
      "Trigonometric" - "Trig. Dots" {
          # Show additional controls
          place .factorf -rely 1 -y -3
          place .offsetf -rely 1 -y -3
      }
   }
}

# Fixup for .algorithm box going blue when the popdown is left
# by clicking outside it

.algorithm configure -postcommand {
   after idle {bind .algorithm.popdown <ButtonPress> {combobox.fixup %x %y .algorithm.popdown}}
   .algorithm configure -postcommand {}
}

proc combobox.fixup {x y w} {
  if {$x < 0 || $y < 0 || $x > [winfo width $w] || $y > [winfo height $w]} {
     after idle {
        .algorithm selection clear; focus .
     }
  }
}

# Manage points list
set points [list]  ;# list of {x y id}

proc points.add {x y} {
   global points
   set color "#8af"
   set r 6
   set id [.canvas create oval [expr $x-$r] [expr $y-$r] [expr $x+$r] [expr $y+$r]]
   .canvas itemconfigure $id -fill $color -outline $color
   .canvas bind $id <Enter> "point.enter $id"
   .canvas bind $id <Leave> "point.leave $id"
   .canvas bind $id <ButtonPress> "point.press $id %x %y"
   .canvas bind $id <Shift-ButtonPress> "point.shiftpress $id %x %y"
   .canvas bind $id <ButtonRelease> "point.release $id %x %y"
   .canvas bind $id <Motion> "point.motion $id %x %y"
   lappend points [list $x $y $id]
   set idx [expr [llength $points]-1]
   return $idx
}
bind .canvas <ButtonPress> "canvas.press %x %y"
bind .canvas <ButtonRelease> "canvas.release %x %y"
proc points.color {idx color} {
   global points
   set p [lindex $points $idx]
   set id [lindex $p 2]
   .canvas itemconfigure $id -fill $color -outline $color
}
proc points.move {idx dx dy} {
   global points
   set p [lindex $points $idx]
   set id [lindex $p 2]; set x [lindex $p 0]; set y [lindex $p 1]
   lset points $idx [list [expr $x+$dx] [expr $y+$dy] $id]
   .canvas move $id $dx $dy
}
proc points.setxy {idx x y} {
   global points
   set p [lindex $points $idx]
   set id [lindex $p 2]
   lset points $idx [list $x $y $id]
   set r 4
   .canvas coords $id [expr $x-$r] [expr $y-$r] [expr $x+$r] [expr $y+$r]
}
proc points.getxy {idx} {
   global points
   set p [lindex $points $idx]
   return [lrange $p 0 1]
}
proc points.getx {idx} {
   global points
   set p [lindex $points $idx]
   return [lindex $p 0]
}
proc points.gety {idx} {
   global points
   set p [lindex $points $idx]
   return [lindex $p 1]
}
proc points.delete {idx} {
   global points
   set p [lindex $points $idx]
   set id [lindex $p 2]
   .canvas delete $id
   set points [lreplace $points $idx $idx]
}
proc points.reset {} {
  global points
  foreach p $points {
    set id [lindex $p 2]
    .canvas delete $id
  }
  set points [list]
}
proc points.id2idx {id} {
  global points
  set len [llength $points]
  for {set idx 0} {$idx < $len} {incr idx} {
    set p [lindex $points $idx]
    if {[lindex $p 2]==$id} {return $idx}
  }
  error "id $id not found in points array"
}
proc points.is_outside {idx} {
  global points
  set p [lindex $points $idx]
  set x [lindex $p 0]; set y [lindex $p 1]
  if {$x < 0 || $x > [winfo width  .canvas]}  { return yes }
  if {$y < 0 || $y > [winfo height .canvas]}  { return yes }
  return no
}
proc points.not_adjacent {idx1 idx2} {
  global settings
  if {[get settings(closepath)]} {
     global points
     set len [llength $points]
     if {$idx1 == 0 && $idx2 == $len-1 || $idx2 == 0 && $idx1 == $len-1} {
         return 0
     } else {
         expr {abs($idx2-$idx1) != 1}
     }
  } else {
     expr {abs($idx2-$idx1) != 1}
  }
}
proc points.insert {idx1 idx2} {
  if {$idx2 < $idx1} {
    lassign [list $idx1 $idx2] idx2 idx1
  }
  global points
  set p [lindex $points $idx1]
  set x1 [lindex $p 0]; set y1 [lindex $p 1]
  set p [lindex $points $idx2]
  set x2 [lindex $p 0]; set y2 [lindex $p 1]

  if {$idx2 != $idx1 + 1} {
    if {[points.not_adjacent $idx1 $idx2]} {
        error "points must be adjacent"
    } else {
        points.add [expr 0.5*($x1+$x2)] [expr 0.5*($y1+$y2)]
        return
    }
  }

  set idx3 [llength $points]
  points.add [expr 0.5*($x1+$x2)] [expr 0.5*($y1+$y2)]
  # move newly created point from end of list to its right place
  set points [linsert $points $idx2 [lindex $points end]]
  set points [lrange $points 0 end-1]
}

# Draw the interpolation (polygon)

proc interpol.delete {} {
  .canvas delete interpol
}
proc pointlist {} {
  global points
  set coords [list]
  set len [llength $points]
  for {set idx 0} {$idx<$len} {incr idx}  {
     if {[points.is_outside $idx]} {continue}
  
     set point [lindex $points $idx]
     set x [lindex $point 0]; set y [lindex $point 1]
     lappend coords $x $y
  }
  return $coords
}

proc interpol.polygon {} {
  global settings
  set coords [pointlist]
  if {[llength $coords] < 4} return
  if {[get settings(closepath)]} {
    lappend coords [lindex $coords 0] [lindex $coords 1]
  }
  .canvas create line $coords -fill "#777" -tag interpol
}
proc interpol.smooth {} {
  interpol.polygon
  .canvas itemconfigure interpol -smooth true
}

proc interpol.random {{count 100}} {
  set w [winfo width .canvas]
  set h [winfo height .canvas]
  for {set i 0} {$i < $count} {incr i} {
    set x [expr {int(rand()*$w)}];
    set y [expr {int(rand()*$h)}];
    .canvas create rectangle $x $y $x $y -tag interpol
  }
}

#### MOST INTERESTING ALGORITHM FOLLOWS ####

package require math::fourier
proc interpol.trig {} {
    global settings

    # 0. Prepare the data
    set coords [pointlist]; set f [list]
    foreach {x y} $coords { lappend f [list $x $y] }
    if { $f == {} } {return {}}
    #----------------------------------------
    # 1. Get coefficients of trig. polynomial
    set c [::math::fourier::inverse_dft $f]
    # 2. Do zero-padding
    set N [llength $f]; set N2 [expr $N/2]
    set M [expr {$N * [get settings(factor)] }]
    set offset [get settings(offset)]
    
    set c [concat  [lrange $c 0 [expr $N2+$offset-1]]  [lrepeat [expr $M-$N] 0]  [lrange $c $N2+$offset end]  ]
    
    # 3. Calculate values of trig. polynomial for all samples
    set y [::math::fourier::dft $c]
    #----------------------------------------
    # 4. Prepare coords list for open / close path
    if {[get settings(closepath)]} {
        # append starting point
        lappend y [lindex $y 0]
    } else {
        # remove last segment (keep up to ending point)
        set y [lrange $y 0 end-[expr [get settings(factor)]-1]]
    }
    return $y
}

#### MOST INTERESTING ALGORITHM ENDS ####


proc interpol.triglines {} {
  set coords [interpol.trig]
  if {[llength $coords]<2} return
  .canvas create line [concat {*}$coords] -fill "#777" -tag interpol
}
proc interpol.trigpoints {} {
  foreach point [interpol.trig] {
     .canvas create rectangle [concat $point $point] -tag interpol
  }
}

proc interpol.do_redraw {} {
  global settings
  .canvas delete interpol
  switch [get settings(algorithm)] {
    "Polygon"   interpol.polygon
    "Tk Smooth" interpol.smooth
    "Trigonometric" interpol.triglines
    "Trig. Dots" interpol.trigpoints
  }
}
proc interpol.tick {} {
  global interpol.needs_redraw
  if {${interpol.needs_redraw}} {
     interpol.do_redraw
     set interpol.needs_redraw no
     after 120 interpol.tick
  } else {
     after 60 interpol.tick
  }
}
set interpol.needs_redraw yes
after idle interpol.tick

proc interpol.redraw {} {
  global interpol.needs_redraw
  set interpol.needs_redraw yes
}


# GUI Event Actions [State Machine]

set state "idle"
pack [ttk::label .state -textvariable state]

proc point.enter {id} {
  global state
  set idx [points.id2idx $id]
  if {$state == "idle"} {
      set state "hover $idx"
      points.color $idx "#adf"
      .canvas configure -cursor crosshair
  } elseif {$state == "choose"} {
      set state "choose $idx"
      points.color $idx "#adf"
      .canvas configure -cursor hand1
  } elseif {"chosen" in $state} {
      set idx2 [lindex $state 1]
      if {[points.not_adjacent $idx $idx2]} return
      set state "chosen $idx2 / choose $idx"
      points.color $idx "#adf"
      .canvas configure -cursor hand1
  }
}
proc point.leave {id} {
  global state
  .canvas configure -cursor left_ptr
  set idx [points.id2idx $id]
  if {"hover" in $state} {
      set state "idle"
      points.color $idx "#8af"
  } elseif {"choose" in $state && "chosen" ni $state} {
      set state "choose"
      points.color $idx "#8af"
  } elseif {"chosen" in $state && "choose" in $state} {
      set idx2 [lindex $state 1]
      set state "chosen $idx2"
      points.color $idx "#8af"
  }
}
proc canvas.press {x y} {
  # Clicks on points are handled by point.press
  if {[.canvas find withtag current] != {} } return
  global state
  if {$state == "idle"} {
      set idx [points.add $x $y]
      set state "created $idx"
      interpol.redraw
  } elseif {$state == "choose"} {
      set state "idle"
      .insert state !pressed
  } elseif {"chosen" in $state && "choose" ni $state} {
      set idx [lindex $state 1]
      points.color $idx "#8af"
      set state "idle"
      .insert state !pressed
  }
}
proc canvas.release {x y} {
  global state
  if {"created" in $state} {
        set state idle
	event generate .canvas <Motion> -x 0 -y 0;
	event generate .canvas <Motion> -x $x -y $y
	
  }
}

proc point.press {id x y} {

  global state
  if {"hover" in $state} {
      set idx [lindex $state 1]
      set state "moving $idx $x $y"
  } elseif {"choose" in $state && "chosen" ni $state} {
      set idx [lindex $state 1]
      points.color $idx yellow
      set state "chosen $idx"
  } elseif {"chosen" in $state && "choose" in $state} {
      set idx1 [lindex $state 1]
      set idx2 [lindex $state end]
      points.color $idx1 "#8af"
      points.insert $idx1 $idx2
      interpol.redraw
      global points; set len [llength $points]
      if {$idx2 > $idx1 && !($idx1==0 && $idx2==$len-2)} {incr idx2}
      set state "hover $idx2"
      .canvas configure -cursor crosshair
      .insert state !pressed
  }
}
proc point.shiftpress {id x y} {
  global state
  if {"hover" in $state} {
      set idx [lindex $state 1]
      points.color $idx yellow
      set state "chosen $idx"
  } else {
      point.press $id $x $y
  }
}
proc point.release {id x y} {
  global state
  if {"moving" in $state} {
    set idx [points.id2idx $id]
    set state "hover $idx"
    if {[points.is_outside $idx]} {
       points.delete $idx
       interpol.redraw
       set state "idle"
    }
  }
}
proc point.motion {id x y} {
  global state
  if {"moving" in $state} {
    lassign $state n idx oldx oldy
    if {$idx != [points.id2idx $id]} {
      error "Motion on a point which has not been clicked"
    }
    set dx [expr $x-$oldx]
    set dy [expr $y-$oldy]
    points.move $idx $dx $dy
    interpol.redraw
    set state "moving $idx $x $y"
  }
}

  # "Delete all" button

proc button.delall {} {
   points.reset
   interpol.delete
}

  # Insert points
proc button.insert {} {
   global state
   set state "choose"
   .insert state pressed
}
