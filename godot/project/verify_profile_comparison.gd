extends SceneTree
const Model=preload("res://scripts/road_model.gd")
const Comparison=preload("res://scripts/profile_comparison.gd")
func design(length,south,offset):
 var model=Model.new()
 model.route=PackedVector3Array([Vector3(0,0,south),Vector3(length,0,south)])
 model.offset=offset
 assert(model.rebuild_alignment()=="")
 return model.edit_state()
func _initialize():
 var current=design(1200,1000,7)
 current.pvi_stations=PackedFloat64Array([0,600,1200])
 current.pvi_heights=PackedFloat64Array([0,60,0])
 current.pvi_lengths=PackedFloat64Array([0,400,0])
 var saved=current.duplicate(true)
 saved.offset=0
 for i in range(saved.pi_route.size()):saved.pi_route[i].z+=100
 var before=current.duplicate(true)
 var result=Comparison.calculate(current,saved,'A, "보관"',123)
 assert(result.ok and result.common_length==1200 and result.rows[0].station==0 and result.rows[-1].station==1200)
 var found=false
 for row in result.rows:
  assert(abs(row.delta-7)<1e-9 and abs(row.separation-100)<1e-8)
  if row.station==600:
   assert(abs(row.current_height-57)<1e-9 and abs(row.saved_height-50)<1e-9)
   assert("current_PVI" in row.events and "saved_PVI" in row.events)
   found=true
 assert(found and current==before)
 var short=design(617.345,1000,0)
 result=Comparison.calculate(current,short,"short",20)
 assert(result.ok and abs(result.common_length-short.pi_route[-1].x)<1e-8 and result.rows[-1].station==result.common_length)
 for row in result.rows:assert(row.station<=result.common_length)
 current.offset=-2
 result=Comparison.calculate(current,saved,"negative",200)
 assert(abs(result.rows[0].delta+2)<1e-9)
 var zeros=design(1000,1000,0)
 result=Comparison.calculate(zeros,zeros,"same",20)
 for row in result.rows:assert(row.delta==0 and row.separation==0)
 for step in [0,NAN,INF,10001]:assert(not Comparison.calculate(current,saved,"bad",step).ok)
 assert(not Comparison.calculate(design(100000,1000,0),design(100000,1100,0),"budget",0.1).ok)
 var invalid=current.duplicate(true)
 invalid.pvi_lengths[1]=5000
 assert(not Comparison.calculate(invalid,saved,"invalid",20).ok)
 print("PASS PROFILE COMPARISON CORE: native parabola/offset sign, displaced paths, union of events, exact common endpoint, zero quantities, immutable input and budget/errors")
 quit(0)
