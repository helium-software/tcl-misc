namespace eval Nspace {

namespace export external

proc external {} {
  puts "external calling \[internal a b c\]"
  internal a b c
}
proc internal {args} {
  puts "internal called with args: $args]"
  puts "internal calling \[real-internal $args $args\]"
  private::real-internal {*}$args {*}$args
}

namespace eval private {
proc real-internal {args} {
  puts "real-internal called with args: $args"
}
}

}
