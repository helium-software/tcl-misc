#!/usr/bin/wish8.5

namespace import ::tcl::mathop::*

ttk::style theme use clam
# TODO: do this with [option]
. configure -bg #dcdad5

ttk::style configure Menubar.TButton -padding {2 0} -width 0 -relief flat
ttk::style map Menubar.TButton -relief {pressed raised}
set frame $::ttk::theme::clam::colors(-frame)
set darker $::ttk::theme::clam::colors(-darker)
ttk::style map Menubar.TButton -background [list disabled $frame pressed $darker]

place [ttk::frame .menubar -relief raised] -x -1 -y -1 -relwidth 1 -width 2

set buttons [list]
proc add_button {name label} {
	ttk::button .menubar.$name -text $label -style Menubar.TButton -takefocus 0
	lappend ::buttons .menubar.$name
}
add_button file Datei
add_button edit Bearbeiten
grid {*}$buttons -padx {3 0} -pady 3


# Menu pulldowns

ttk::style configure MenuEntry.TButton -padding {2 0} -width 0 -relief flat
ttk::style map MenuEntry.TButton -background [list disabled $frame active "#bab5ab" pressed "#bab5ab"]
ttk::style layout MenuEntry.TButton {Button.border -sticky nswe -border 1 -children {Button.padding -sticky nswe -children {Button.label -sticky nsw}}}


frame .file-outer -background "#9e9a91"
pack [ttk::frame .file] -in .file-outer -fill both -expand true -padx 1 -pady 1
grid [ttk::button .file.new -text "Neu\t\tCtrl-N" -style MenuEntry.TButton] -sticky we
grid [ttk::button .file.open -text "Öffnen\t\tCtrl-O" -style MenuEntry.TButton] -sticky we
grid [ttk::button .file.close -text "Schließen\t\tCtrl-w" -style MenuEntry.TButton] -sticky we
grid [frame .file.sep -background "#9e9a91"] -sticky we -padx 3 -pady 3
grid [ttk::button .file.save -text "Speichern\t\tCtrl-S" -style MenuEntry.TButton] -sticky we
grid [ttk::button .file.saveas -text "Speichern unter\tCtrl-s" -style MenuEntry.TButton] -sticky we
grid [ttk::button .file.rename -text "Umbenennen\tF2" -style MenuEntry.TButton] -sticky we
.menubar.file state pressed
grid [ttk::button .file.delete -text "Löschen" -style MenuEntry.TButton] -sticky we
.menubar.file state pressed
after idle {update idletasks; place .file-outer -x [+ -1 [winfo x .menubar.file]] -y [+ [winfo y .menubar.file] [winfo height .menubar.file]]}
