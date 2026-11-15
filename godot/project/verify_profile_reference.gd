extends SceneTree
const Model=preload("res://scripts/road_model.gd")
const Reference=preload("res://scripts/plan_reference.gd")
func _initialize():
 var model=Model.new()
 model.demo()
 model.route=PackedVector3Array([Vector3(600,0,1000),Vector3(1800,0,1000)])
 model.pvi_stations=PackedFloat64Array([0,600,1200])
 model.pvi_heights=PackedFloat64Array([0,60,0])
 model.pvi_lengths=PackedFloat64Array([0,400,0])
 model.offset=7
 assert(model.rebuild_alignment()=="")
 var before=model.edit_state()
 var reference=Reference.build(before)
 assert(reference.ok and reference.length==1200 and reference.low==7 and reference.high==67)
 for station in [0,123.456,400,600,800,1199.999,1200]:
  var saved=reference.alignment.sample(station)
  var current=model.sample(station)
  assert(abs(saved.elevation-current.elevation)<1e-9)
 for i in range(1001):
  var station=reference.length*i/1000.0
  assert(abs(Reference.profile_height(reference,station)-(reference.alignment.sample(station).elevation+reference.offset))<1e-9)
 assert(Reference.profile_height(reference,-0.001)==null and Reference.profile_height(reference,1200.001)==null and Reference.profile_height(reference,NAN)==null)
 assert(abs(reference.alignment.sample(600).elevation+reference.offset-57)<1e-9)
 assert(abs(reference.alignment.sample(400).elevation+reference.offset-47)<1e-9)
 model.pvi_heights[1]+=20
 model.offset=12
 assert(model.rebuild_alignment()=="")
 assert(abs(reference.alignment.sample(600).elevation+reference.offset-57)<1e-9 and before.pvi_heights[1]==60)
 assert(model.sample(600).elevation+model.offset>57)
 model.pvi_stations=PackedFloat64Array([0,300,600,900,1200])
 model.pvi_heights=PackedFloat64Array([0,30,-10,25,0])
 for lengths in [PackedFloat64Array([0,150,200,100,0]),PackedFloat64Array([0,0,0,0,0])]:
  model.pvi_lengths=lengths
  assert(model.rebuild_alignment()=="")
  var mixed=Reference.build(model.edit_state())
  for i in range(1001):
   var station=mixed.length*i/1000.0
   assert(abs(Reference.profile_height(mixed,station)-(mixed.alignment.sample(station).elevation+mixed.offset))<1e-8)
 print("PASS PROFILE REFERENCE CORE: exact parabola, BVC/EVC/endpoints, applied offset, conservative bounds and immutable native reference")
 quit(0)
