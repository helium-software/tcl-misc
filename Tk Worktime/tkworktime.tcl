#!/usr/bin/wish8.5
# Worktime logger | Tibor Stolz, March 2013
# Feature-complete, but the coding could still be made simpler and more readable.
ttk::style theme use clam
namespace import tcl::mathfunc::* tcl::mathop::*
#package require snack ;# only if you need play_sound_snack


### 1 # Project directory handling ###

## Global variables
set DIRECTORY ~/tkworktime  ;# directory in which to store log & counter files
file mkdir $DIRECTORY

## Get list of projects
proc list_projects {} {
	set logs [list]
	set projects [list]
	foreach filename [glob -nocomplain -directory $::DIRECTORY *.log.tsv] {
		lappend logs [string range [file tail $filename] 0 end-8]
	}
	foreach filename [glob -nocomplain -directory $::DIRECTORY *.count.tsv] {
		set projectname [string range [file tail $filename] 0 end-10]
		if {$projectname in $logs} {
			lappend projects $projectname
		}
	}
	return $projects
}

proc last_opened_project {} {
	set project ""
	set maxmtime -1
	foreach filename [glob -nocomplain -directory $::DIRECTORY *.log.tsv] {
		set mtime [file mtime $filename]
		if {$mtime > $maxmtime} {
			set project [string range [file tail $filename] 0 end-8]
	}	}
	return $project
}

## Remove a project from disk
proc remove_project {projectname} {
	set answer [tk_messageBox -message [string map [list * $projectname] [localize DeleteMessage]] \
		-title [localize DeleteTitle] -icon warning -type okcancel]
	if {$answer=="cancel"} {return "cancelled"}
	file delete [file join $::DIRECTORY $projectname.log.tsv]
	file delete [file join $::DIRECTORY $projectname.count.tsv]
	return "done"
}
## Create files for a project, such that it can be found by [list_projects]
proc create_project {projectname} {
	close [open [file join $::DIRECTORY $projectname.log.tsv] w]
	write_countfile [list 2.1.1970 0:00 0:00] [file join $::DIRECTORY $projectname.count.tsv]
}


### 2 # Log File handling ###

## Shared subprocs for generating TSV log file names
## The "filename" argument of all following procedures is only intended
## for debugging.
proc open_logfile {filename args} {
	if {$filename==""} {
		set filename [file join $::DIRECTORY $::PROJECT.log.tsv]
	}
	return [open $filename {*}$args]
}
proc logfile_isempty {filename} {
	if {$filename==""} {
		set filename [file join $::DIRECTORY $::PROJECT.log.tsv]
	}
	if {![file exists $filename]} {return yes}
	if {[file size $filename]==0} {return yes}
	return no
}

## Read data from TSV log file
## Returns data as list of [list $date $duration $task] elements
proc readlogfile {{filename ""}} {
	set channel [open_logfile $filename r]
	# remove headings line
	gets $channel
	
	set data [list]
	while {[gets $channel Line]>=0} {
		if {$Line == ""} continue
		set fields [split $Line \t]
		# Verify data (incomplete, but unimportant)
		if {[llength $fields] != 3} {error "Bad data format at '$Line': #columns must be 3"}
		# Translate newlines in 3rd field (task description)
		lset fields 2 [string map {{\\} \n} [lindex $fields 2]]
		lappend data $fields
	}
	close $channel
	return $data
}

## Append a dataset [list $date $duration $task] or a newline to a TSV log file
## The heading is generated automatically on an empty file.
proc appendlogfile {dataset {filename ""}} {	
	set channel [open_logfile $filename a]
	if {[logfile_isempty $filename]} {
		puts $channel [join [localize TSVloghead] \t]
	}
	if {$dataset!="\n"} {
		# translate newlines in 3rd field (task description)
		lset dataset 2 [string map {\n {\\}} [lindex $dataset 2]]
		puts $channel [join $dataset \t]
	} else {
		puts $channel ""
	}
	close $channel
}


### 3 # Counter File Handling ###

proc open_countfile {filename args} {
	if {$filename==""} {
		set filename [file join $::DIRECTORY $::PROJECT.count.tsv]
	}
	return [open $filename {*}$args]
}

proc read_countfile {{filename ""}} {
	set channel [open_countfile $filename r]
	set data [read -nonewline $channel]
	close $channel
	return [split $data \t]
}

proc write_countfile {data {filename ""}} {
	set channel [open_countfile $filename w]
	puts $channel [join $data \t]
	close $channel
}


### 4 Saved-state file (contains non-project-specific information) ###

# "filename" is only intended for debugging and diagnostics
proc write_statefile {{filename ""}} {
	if {$filename==""} {set filename [file join $::DIRECTORY SAVEDSTATE.txt]}
	
	set channel [open $filename w]
	puts $channel "[localize {Uncommitted Timespan}]: $::SECONDS s"
	puts $channel ""
	puts $channel [.text get 1.0 end-1char]
	close $channel
}
proc read_statefile {{filename ""}} {
	if {$filename==""} {set filename [file join $::DIRECTORY SAVEDSTATE.txt]}
	set ::SECONDS 0
	if {! [file exists $filename]} return
	
	set channel [open $filename r]
	regexp {([0-9]*) s$} [gets $channel] -> ::SECONDS
	gets $channel ;# read the newline
	.text delete 1.0 end
	.text insert 1.0 [read -nonewline $channel]
	close $channel
	
	buttons_Update
}

# The only call to read_statefile is just at startup:
after idle {update; read_statefile; display_Update}

# Write statefile when the application is closed:
wm protocol . WM_DELETE_WINDOW {set StartStop Stopped; catch write_statefile; exit}
wm protocol . WM_SAVE_YOURSELF {set StartStop Stopped; catch write_statefile}


### 5 # GUI Build-Up ###

wm command . [info script]

# execute after all procs are available
after idle {

wm title . [localize WindowTitle]

ttk::frame .counters
ttk::label .counters.task -text [localize Task]
ttk::label .counters.today -text [localize Today]
ttk::label .counters.total -text [localize Total]
ttk::label .counters.tasktime -textvariable counters.task -font TkCaptionFont -anchor e
ttk::label .counters.todaytime -textvariable counters.today -font TkCaptionFont -anchor e
ttk::label .counters.totaltime -textvariable counters.total -font TkCaptionFont -anchor e

grid anchor .counters center
grid .counters.task .counters.tasktime  -sticky we -padx 3 -pady 1
grid .counters.today .counters.todaytime  -sticky we -padx 3 -pady 1
grid .counters.total .counters.totaltime  -sticky we -padx 3 -pady 1

ttk::frame .startstop
ttk::radiobutton .start -text [localize Start] -variable StartStop -value Started -width 5 -style Toolbutton
ttk::radiobutton .stop -text [localize Stop] -variable StartStop -value Stopped -width 5 -style Toolbutton
ttk::style configure Toolbutton -padding 6
#
grid anchor .startstop center
grid .start -in .startstop -padx 2 -pady 2
grid .stop -in .startstop -padx 2 -pady 2

ttk::frame .text&enter
text .text -width 40 -height 3 -wrap word
	ttk::frame .text&enter.textborder
	pack .text -in .text&enter.textborder -fill both -expand true
	# Clam-theme specific setup
	.text configure -border 0 -highlightthickness 0
	.text&enter.textborder configure -relief solid
	pack configure .text -padx 1 -pady 1
grid .text&enter.textborder -columnspan 3 -padx 3 -pady 3
ttk::button .clear -text [localize Clear] -padding {0 -1} -width 0 -takefocus 0
ttk::button .sub1min -text [localize Sub1Min] -padding {0 -1} -width 0 -takefocu 0
ttk::button .enter -text [localize Enter] -padding 1 -width 0 -takefocus 0
grid .sub1min x .enter -in .text&enter -padx 3 -pady {0 3} -sticky e
# Note that the button .clear has been placed nowhere. If you really want it,
# replace 'x' by '.clear' in the above grid command.
grid .sub1min -sticky w

ttk::frame .project&log
ttk::label .projectl -text [localize Project:]
ttk::combobox .project
ttk::button .viewlog -text [localize ViewLog] -padding 0 -width 0 -takefocus 0
#
grid .projectl -in .project&log -sticky w -padx 1
grid .project -in .project&log -padx 2
grid .viewlog -in .project&log -padx 2 -pady 3 -sticky se
grid rowconfigure .project&log 2 -weight 1

set counters.task ‒:‒‒  ;# you should never see this
set counters.today ‒:‒‒
set counters.total ‒:‒‒
grid .counters .startstop .text&enter [ttk::separator .separator -orient vertical] .project&log -sticky sn -padx 4
grid .separator -pady 4 -ipadx 1
. configure -background #dcdad5
wm resizable . 0 0
}

## Debugger window
#toplevel .debug
#grid [label .debug.l1 -text SECONDS] [label .debug.l2 -textvariable SECONDS]
#grid [label .debug.l3 -text STARTTIME] [label .debug.l4 -textvariable STARTTIME]
#grid [label .debug.l5 -text STATE] [label .debug.l6 -textvariable STATE]
#grid [label .debug.l7 -text CHIMESTATE] [label .debug.l8 -textvariable CHIMESTATE]


### 6 # Project Selector ###

## Global variables

# Currently opened project
set PROJECT ""
# Its data (list of [list date duration task] items)
set DATA [list]

## Combobox widget bindings
after idle {
bind .project <Return> {event generate %W <<ComboboxOpen>>; ttk::combobox::Post %W}
bind .project <ButtonPress-1> {
	if {! [string match *textarea [%W identify %x %y]]} {event generate %W <<ComboboxOpen>>}
}

bind .project <<ComboboxOpen>> .project.update_list
bind .project <<ComboboxSelected>> .project.selected
}

## Update combobox list on opening
proc .project.update_list {} {
	destroy .project.popdown.msg
	set projects [list_projects]
	if {$projects != {}} {
		set values $projects
		if {[.project get] in $projects} {
			# already existing project entered in combobox: provide option to delete
			lappend values "" [string map [list * [.project get]] [localize "Delete »*«"]]
		} elseif {[.project get]!=""} {
			# new project name entered in combobox: provide option to create
			lappend values "" [string map [list * [.project get]] [localize "Create »*«"]]
		}
		.project configure -values $values
	} else {
		# special case: no projects in folder
		if {[.project get]==""} {
			.project configure -values {}
			if {![winfo exists .project.popdown]} {ttk::combobox::Post .project}
			ttk::label .project.popdown.msg -text [localize EnterProjectName] -wraplength 178
			grid .project.popdown.msg -in .project.popdown -column 0 -row 0 -columnspan 1 -rowspan 1 -ipadx 0 -ipady 0 -padx 0 -pady 0 -sticky nesw
		} else {
			.project configure -values [list [string map [list * [.project get]] [localize "Create »*«"]] ]
		}
	}
}

## Handle selection of a project or create/delete action
proc .project.selected {} {
	if {[.project get]==""} {
		# Empty line selected -> no-op
		.project set $::PROJECT
	} elseif {[string match [localize "Create »*«"] [.project get]]} {
		# Create project, and open it
		regexp [string map {* (.*)} [localize "Create »*«"]] [.project get] -> newproject
		create_project $newproject
		project_open $newproject
	} elseif {[string match [localize "Delete »*«"] [.project get]]} {
		# correct combobox contents
		.project set $::PROJECT
		# Delete project, open next recent
		set status [remove_project $::PROJECT]
		if {$status=="done"} project_try_opening_recent
	} else {
		# Change project
		project_open [.project get]
	}
}


## Implementation of subprocedures
proc project_open {projectname} {
	set ::PROJECT $projectname
	set ::DATA [readlogfile]
	lassign [read_countfile] ::LASTDATE ::DAYTIME ::TOTALTIME
	display_Update
	.project set $projectname
	if {[winfo exists .logwindow]} {
		viewlog_prepare -noraise
		viewlog_fill $::DATA
	}
	# Reset day worktime counter, if necessary
	if {$::LASTDATE != [timestamp_to_date [clock seconds]]} {
		set ::DAYTIME 0:00
		display_Update
	}
	buttons_Update
}
proc project_open_none {} {
	set ::DAYTIME 0:00
	set ::TOTALTIME 0:00
	display_Update
	.project set ""
	set ::PROJECT ""
	destroy .logwindow
	buttons_Update
}
proc project_try_opening_recent {} {
	if {[list_projects]!={}} {
		project_open [last_opened_project]
	} else {
		project_open_none
	}
}
# this chooses project at startup
after idle project_try_opening_recent


### 7 # Start/Stop Clock Behaviour ###

## Global variables
set SECONDS 0
set STARTTIME 0
set STATE Stopped
after idle set StartStop Stopped

trace add variable StartStop write start_stop
proc start_stop {args} {
	if {$::STATE == $::StartStop} return ;# if same button pressed again
	set ::STATE $::StartStop
	switch $::StartStop Started {
		set ::STARTTIME [clock seconds]
		displayticker_start
		standby_detect_start
	} Stopped {
		incr ::SECONDS [expr [clock seconds]-$::STARTTIME]
		displayticker_stop
		standby_detect_stop
	}
}

## Global keyboard shortcut: Control-Space toggles Start/Stop state
bind all <Control-space> {
	switch $StartStop Started {set StartStop Stopped} Stopped {set StartStop Started}
}

## Display updates and ticker
proc displayticker_start {} displayticker_tick
proc displayticker_tick {} {
	set seconds [expr $::SECONDS + [clock seconds]-$::STARTTIME]
	# update fields from $seconds
	set ::counters.task [seconds_to_string $seconds]
	set ::counters.today [seconds_to_string [+ $seconds [string_to_seconds $::DAYTIME]]]
	set ::counters.total [seconds_to_string [+ $seconds [string_to_seconds $::TOTALTIME]]]
	# this enables the Enter button if >=60 seconds have been counted
	buttons_Update
	# if 1 hour has been reached, play a chimes sound
	set conf {60 bell.wav 70 bell.wav 80 bell.wav 90 bell.wav}
	set span_seconds [expr [clock seconds]-$::STARTTIME]
	if {$span_seconds < 120} {set ::CHIMESTATE 0}
	foreach {minutes sound} $conf {
		incr i
		if {$span_seconds >= [* 60 $minutes] && $::CHIMESTATE < $i} {
			play_sound $sound
			set ::CHIMESTATE $i
			break
		}
	}
	# calculate next firing time and schedule a tick
	after cancel displayticker_tick
	after [expr {1000*(61-$seconds%60)}] displayticker_tick
}
proc display_update_running {} displayticker_tick

proc display_update_stopped {} {
	# update fields from ::SECONDS
	set ::counters.task [seconds_to_string $::SECONDS]
	set ::counters.today [seconds_to_string [+ $::SECONDS [string_to_seconds $::DAYTIME]]]
	set ::counters.total [seconds_to_string [+ $::SECONDS [string_to_seconds $::TOTALTIME]]]
}
proc displayticker_stop {} {
	after cancel displayticker_tick
	display_update_stopped
	buttons_Update
}

## This Update procedure is intended to be called from outside
proc display_Update {} {
	switch $::STATE \
		Started display_update_running \
		Stopped display_update_stopped
}


## Updates enabled/disabled state of GUI elements
proc buttons_Update {} {
	if {$::PROJECT==""} {
		.viewlog state disabled
		.enter state disabled
	} else {
		.viewlog state !disabled
		if {$::STATE=="Stopped"} {
			set seconds $::SECONDS
		} else {
			set seconds [expr $::SECONDS + [clock seconds]-$::STARTTIME]
		}
		if {$seconds >= 60} {.enter state !disabled} else {.enter state disabled}				
	}
}


## Sound output
proc play_sound {filename} {
	set filename [file join [file dirname [info script]] $filename]
	if {[string match "*.ogg" $filename]} {
		exec -ignorestderr ogg123 $filename 2>/dev/null &
	} else {  #if you don't have sox, replace "play" by "aplay"
		exec -ignorestderr play $filename 2>/dev/null &
	}
}
# try this if there is no non-GUI sound player on your system
# (needs the Snack library)
proc play_sound_snack {soundfile} {
	if {[info commands $soundfile]==$soundfile} {
		$soundfile play
	} else {
		package require snack
		snack::sound $soundfile -file [file join [file dirname [info script]] $soundfile]
		$soundfile play
	}
}


## Time formatting
proc string_to_seconds {string} {
	scan $string %d:%d hours minutes
	return [expr {($hours*60+$minutes)*60}]
}
proc seconds_to_string {seconds} {
	set minutes [expr {$seconds/60}]
	set hours [expr {$minutes/60}]
	set minutes [expr {$minutes-$hours*60}]
	return [format %d:%02d $hours $minutes]
}


## Standby Detect
proc standby_detect_tick {} {
	if {$::STATE=="Stopped"} return
	global standby_detect_T
	set now [clock seconds]
	set skew [expr {$now - $standby_detect_T - 10}]
	set standby_detect_T $now
	if {$skew > 30} {
		puts "Detected standby skew of $skew seconds"
		incr ::STARTTIME $skew
	}
	after 10000 standby_detect_tick
}
proc standby_detect_start {} {
	set ::standby_detect_T [clock seconds]
	standby_detect_tick
}
proc standby_detect_stop {} {
	after cancel standby_detect_tick
}


## Style of Start/Stop buttons
namespace eval ttk::theme::clam {
	ttk::style configure Toolbutton -relief raised
	ttk::style map Toolbutton \
		-background [list \
			disabled $colors(-frame) \
			selected $colors(-darker) \
			pressed $colors(-dark) \
			active $colors(-lighter)] \
		-lightcolor [list selected $colors(-darker) pressed $colors(-dark)] \
		-darkcolor [list selected $colors(-darker) pressed $colors(-dark)]
}


### 8 # Enter Button ###

proc timestamp_to_date {timestamp} {
	string map {" " ""} [clock format $timestamp -format "%e.%N.%Y"]
}
proc date_to_timestamp {date} {
	clock scan $date -format "%e.%N.%Y"
}
proc today_is {date} {
	expr {$date == [timestamp_to_date [clock seconds]]}
}

proc enter_timespan {} {
	set ::StartStop Stopped
	if {$::SECONDS==0} return
	if {$::SECONDS<60} {set ::SECONDS 60}

	# Write log and countfile
	set last_timespan_date [lindex $::DATA end 0]
	set today [timestamp_to_date [clock seconds]]
	if {$today!=$last_timespan_date} {
		appendlogfile \n
	}
	set dataset [list $today [seconds_to_string $::SECONDS] [.text get 1.0 end-1c]]
	lappend ::DATA $dataset
	appendlogfile $dataset
	write_countfile [list $today ${::counters.today} ${::counters.total}]

	# Reset day worktime counter, if necessary
	if {$today!=$::LASTDATE} {
		set ::counters.today [seconds_to_string $::SECONDS]
	}
	set ::LASTDATE $today
	# Reset task counter
	set ::DAYTIME ${::counters.today}
	set ::TOTALTIME ${::counters.total}
	set ::SECONDS 0
	display_update_stopped
	buttons_Update
}
after idle {
	.enter configure -command enter_timespan
	buttons_Update
}


### 9 # Clear / Subtract 1 Minute Button ###

proc clear_timespan {} {
	set ::StartStop Stopped
	set ::SECONDS 0
	display_update_stopped
	buttons_Update
}
proc subtract_1min {{amount 60}} {
	switch $::STATE "Stopped" {
		global SECONDS
		set SECONDS [expr {max(0,$SECONDS-$amount)}]
	} "Started" {
		global STARTTIME SECONDS
		# try first decreasing the SECONDS counter by 60 ($amount);
		# add the rest ($increment) to STARTTIME
			set decrement [expr {min($SECONDS,$amount)}]
			incr SECONDS [- $decrement]
			set increment [expr {$amount-$decrement}]
		set now [clock seconds]
		set STARTTIME [expr {min($now,$STARTTIME+$increment)}]
	}
	display_Update
	buttons_Update
}
after idle {
	.clear configure -command clear_timespan
	.sub1min configure -command subtract_1min
	# subtract 10 minutes on shift-click
	bind .sub1min <Shift-ButtonRelease-1> {
		subtract_1min 600
		.sub1min state !pressed
		break
	}
}


### 10 # View Log as table ###

proc viewlog_prepare {{-noraise ""}} {
	if {[winfo exists .logwindow]} {
		if {${-noraise}!="-noraise"} {raise .logwindow}
		.logwindow.text configure -state normal
		.logwindow.text delete 1.0 end
		return
	}
	toplevel .logwindow -bg white
	wm title .logwindow [localize LogWindowTitle]
	text .logwindow.text -padx 18 -pady 10 -highlightthickness 0 -border 0 -wrap word -spacing1 2
	pack .logwindow.text -fill both -expand true -side left
	.logwindow.text configure -font "TkDefaultFont"
	.logwindow.text tag configure heading -font "TkHeadingFont" -spacing1 0 -spacing3 2
	ttk::scrollbar .logwindow.scroll -orient vertical -command ".logwindow.text yview"
	pack .logwindow.scroll -fill y -side right -padx 2 -pady 2
	.logwindow.text configure -yscrollcommand ".logwindow.scroll set"
	# Calculate tabs
	set date_width [max [font measure TkDefaultFont 99.19.9999] [font measure TkHeadingFont [localize Date]]]
	set duration_width [max [font measure TkDefaultFont 99:99] [font measure TkHeadingFont [localize Duration]]]
	set tabs [list [+ 20 $date_width] [+ 40 $date_width $duration_width]]
	.logwindow.text configure -tabs $tabs
	.logwindow.text tag configure extraline -lmargin1 [lindex $tabs 1] -lmargin2 [lindex $tabs 1] -spacing1 0
}

proc viewlog_fill {data} {
	.logwindow.text insert end "[localize Date]\t[localize Duration]\t[localize Task]\n" heading
	foreach item $data {
		lassign $item date duration task
		# print newline if date is not the same as in the previous line
		if {[info exists prev_date] && $date != $prev_date} {
			.logwindow.text insert end "\n" extraline
		}
		set prev_date $date
		# print the data
		.logwindow.text insert end $date\t normal $duration\t normal
		.logwindow.text insert end $task extraline \n normal
	}
	.logwindow.text delete end-1char ;# erase last newline
	.logwindow.text configure -state disabled
}

after idle {
.viewlog configure -command {viewlog_prepare; viewlog_fill $::DATA}
}


### X # Localized strings ###

proc localize {string} {
	if {[dict exists $::localized $::localized_key $string]} {
		return [dict get $::localized $::localized_key $string]
	} else {
		return $string
	}
}

## Build up the Dictionary
dict set localized C C ""  ;# dummy language, dictionary that contains nothing

dict set localized de TSVloghead [list "Datum   " Dauer Aufgabe]
dict set localized en TSVloghead [list Date Duration Task]
dict set localized de "Uncommitted Timespan" "Nicht zugeordnete Zeit"
dict set localized de Date Datum
dict set localized de Duration Dauer
dict set localized de Task Aufgabe
dict set localized de WindowTitle "Arbeitsprotokoll"
dict set localized en WindowTitle "Tk Worktime"
dict set localized de LogWindowTitle "Arbeitsprotokoll : Chronik"
dict set localized en LogWindowTitle "Tk Worktime : Log"
dict set localized de Task Aufgabe
dict set localized de Today Heute
dict set localized de Total Gesamt
dict set localized de Clear Rücksetzen
dict set localized de Sub1Min "1 min abziehen"
dict set localized en Sub1Min "Subtract 1 minute"
dict set localized de Enter Eintragen
dict set localized de Stop Stopp
dict set localized de Project: Projekt:
dict set localized de "Create »*«" "Erstelle »*«"
dict set localized de "Delete »*«" "Lösche »*«"
dict set localized de DeleteMessage "Projekt »*« wird gelöscht. Fortfahren?"
dict set localized en DeleteMessage "Okay to delete project\n»*«?"
dict set localized de DeleteTitle "Projekt löschen"
dict set localized en DeleteTitle "Delete project"
dict set localized de EnterProjectName "Geben Sie im obigen Feld einen Projektnamen ein und drücken Sie Enter, um ein neues Projekt zu erstellen."
dict set localized en EnterProjectName "Enter a project name in the field above and press the enter key to create a new project."
dict set localized de ViewLog "Chronik ansehen"
dict set localized en ViewLog "View Log…"

## Find the language key to use
set localized_key $env(LANG)
# Try full LANG
if {![dict exists $localized $localized_key]} {
	# If that fails, try first part of LANG, e.g. "de_CH.UTF-8" -> "de"
	regexp {[a-z]*} $localized_key localized_key
	if {![dict exists $localized $localized_key]} {
		# If that fails too, fall back to English
		set localized_key en
}	}

