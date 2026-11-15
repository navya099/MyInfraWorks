extends SceneTree
const Model=preload("res://scripts/road_model.gd")
const Table=preload("res://scripts/station_table.gd")
const View=preload("res://scripts/station_range_table.gd")
func _initialize():
 var model=Model.new()
 model.demo()
 model.route=PackedVector3Array([Vector3(600,0,1000),Vector3(1600,0,1000)])
 model.pvi_stations=PackedFloat64Array([0,500,1000])
 model.pvi_heights=PackedFloat64Array([100,150,100])
 model.pvi_lengths=PackedFloat64Array([0,200,0])
 assert(model.rebuild_alignment()=="")
 var report=Table.calculate_job(model.snapshot(),1)
 var before=report.rows.duplicate(true)
 var selected=report.rows.filter(View.is_boundary)
 var stations=[]
 for row in selected:stations.append(row.station)
 assert(stations==[0.0,400.0,500.0,600.0,1000.0])
 assert("regular" in selected[1].events and "vertical_curve_start" in selected[1].events)
 assert(report.rows==before)
 report=Table.calculate_job(model.snapshot(),100,{"begin":425.25,"end":575.75})
 selected=report.rows.filter(View.is_boundary)
 assert(selected.size()==3 and selected[0].station==425.25 and selected[-1].station==575.75)
 assert("range_start" in selected[0].events and "range_end" in selected[-1].events)
 for tag in ["start","end","range_start","range_end","PI","PVI","geometry_boundary","vertical_curve_start","vertical_curve_end"]:
  assert(View.is_boundary({"events":tag}))
  assert(View.is_boundary({"events":"regular|"+tag}))
 assert(not View.is_boundary({"events":"regular"}) and not View.is_boundary({"events":""}))
 model.route=PackedVector3Array([Vector3(100,100,900),Vector3(900,100,900),Vector3(900,100,100)])
 model.radii=PackedFloat64Array([0,300,0])
 model.spirals=PackedFloat64Array([0,50,0])
 model.pvi_stations=PackedFloat64Array()
 assert(model.rebuild_alignment()=="")
 report=Table.calculate_job(model.snapshot(),1)
 selected=report.rows.filter(View.is_boundary)
 var pi=false
 var boundary=false
 for row in selected:
  if "PI" in row.events:pi=true
  if row.station>0 and row.station<report.length and "geometry_boundary" in row.events:boundary=true
 assert(pi and boundary and selected.size()<report.rows.size())
 print("PASS STATION EVENTS CORE: all boundary types, coincident regular tags, parabola BVC/PVI/EVC, clipped endpoints, spiral/PI boundaries and immutable source rows")
 quit(0)
