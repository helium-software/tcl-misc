package provide testpkgN 1.0

namespace eval testpkgN {

variable member
proc method {args} {
   variable member
   if {$args==""} {
      # get member
      return $member
   } else {
      set member $args
   }
}

}
