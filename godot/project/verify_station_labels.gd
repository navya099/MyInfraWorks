extends SceneTree
const Dxf=preload("res://scripts/section_dxf_geometry.gd")
func _initialize():
 assert(Dxf.station_label(0)=="0+000.000")
 assert(Dxf.station_label(1234.567)=="1+234.567")
 assert(Dxf.station_label(999.9996)=="1+000.000")
 assert(Dxf.station_label(98235)=="98+235.000")
 assert(Dxf.station_label(999.96,1)=="1+000.0")
 assert(Dxf.station_label(1234.567,2)=="1+234.57")
 assert(Dxf.station_label(999.6,0)=="1+000")
 print("PASS STATION LABELS: zero, fractional, kilometre rounding and long route")
 quit(0)
