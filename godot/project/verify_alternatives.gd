extends SceneTree
const Model=preload("res://scripts/road_model.gd")
const Library=preload("res://scripts/design_alternatives.gd")
var failures=0
func check(value,label):
 if value:print("PASS "+label)
 else:
  failures+=1
  push_error("FAIL "+label)
func _initialize():
 var model=Model.new()
 model.demo()
 model.route=PackedVector3Array([Vector3(600,150,1000),Vector3(1800,170,1000)])
 assert(model.rebuild_alignment()=="")
 var library=Library.new()
 check(library.capture("A",model)=="","capture valid design")
 var original=library.entries[0].design.duplicate(true)
 model.route[1]=Vector3(2000,170,1200)
 assert(model.rebuild_alignment()=="")
 check(library.entries[0].design==original,"capture is immutable during later edits")
 check(library.capture("A",model)!="" and library.capture(" ",model)!="","duplicate/empty names rejected")
 check(library.capture("B",model)=="" and library.rename(1,"A")!="","unique rename required")
 var serialized=library.serialize()
 check(serialized.size()==2 and serialized[0].keys().size()==2 and not serialized[0].design.has("source") and not serialized[0].design.has("terrain"),"saved alternatives exclude DEM and derived meshes")
 var decoded=Library.decode(serialized,model.terrain,model.source)
 check(decoded.ok and decoded.entries.size()==2 and decoded.entries[0].design==original,"validate/normalize roundtrip")
 var invalid=serialized.duplicate(true)
 invalid[1].design.pi_route[1]=Vector3(100000,0,0)
 check(not Library.decode(invalid,model.terrain,model.source).ok,"out-of-terrain alternative rejects entire list")
 invalid=serialized.duplicate(true)
 invalid[0].design.pvi_stations=PackedFloat64Array()
 check(not Library.decode(invalid,model.terrain,model.source).ok,"missing endpoint profile rejected rather than regenerated")
 invalid=serialized.duplicate(true)
 invalid[0].design.cut_slope=NAN
 check(not Library.decode(invalid,model.terrain,model.source).ok,"nonfinite parameters rejected")
 for i in range(2,20):assert(library.capture("Alt"+str(i),model)=="")
 check(library.capture("Too many",model)!="","20 alternative limit")
 if failures==0:print("PASS DESIGN ALTERNATIVES CORE")
 quit(0 if failures==0 else 1)
