package provide testmodN 1.0

namespace eval testmodN {

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
