extends SceneTree
const Model=preload("res://scripts/road_model.gd")
const Geometry=preload("res://scripts/profile_dxf_geometry.gd")
func save_fixture(name,result):
 assert(result.ok)
 var file=FileAccess.open("user://"+name,FileAccess.WRITE)
 assert(file!=null)
 file.store_string(result.text)
 file.close()
func _initialize():
 var heights=PackedFloat64Array()
 heights.resize(1301*3)
 heights.fill(0)
 var terrain={"Nx":1301,"Ny":3,"Dx":1.0,"Dy":100.0,"Min":0.0,"Max":0.0,"Heights":heights}
 var model=Model.new()
 model.terrain=terrain
 model.source=terrain
 model.route=PackedVector3Array([Vector3(0,0,100),Vector3(1200,0,100)])
 model.pvi_stations=PackedFloat64Array([0,600,1200])
 model.pvi_heights=PackedFloat64Array([0,60,0])
 model.pvi_lengths=PackedFloat64Array([0,400,0])
 model.offset=7
 assert(model.rebuild_alignment()=="")
 var before=model.edit_state()
 var result=Geometry.calculate_job(model.snapshot(),123,200,1000,10)
 assert(result.ok and result.stations[0]==200 and result.stations[-1]==1000 and 400.0 in result.stations and 600.0 in result.stations and 800.0 in result.stations)
 assert(result.datum==0 and result.missing==0 and model.edit_state()==before)
 save_fixture("profile-dxf-parabola.dxf",result)
 result=Geometry.calculate_job(model.snapshot(),300,125,1125,1)
 for i in range(1,result.stations.size()):assert(result.stations[i]-result.stations[i-1]<=300.000001)
 save_fixture("profile-dxf-equal.dxf",result)
 var hole=terrain.duplicate(true)
 var values=heights.duplicate()
 for y in range(3):values[y*1301+600]=NAN
 hole.Heights=values
 model.source=hole
 result=Geometry.calculate_job(model.snapshot(),20,400,800,10)
 assert(result.ok and result.missing>0 and result.ground_runs==2)
 save_fixture("profile-dxf-gap.dxf",result)
 values.fill(NAN)
 hole.Heights=values
 result=Geometry.calculate_job(model.snapshot(),20,400,800,10)
 assert(result.missing==result.stations.size() and result.ground_runs==0)
 save_fixture("profile-dxf-no-ground.dxf",result)
 model.source=terrain
 model.pvi_heights=PackedFloat64Array([0,30,-30])
 assert(model.rebuild_alignment()=="")
 result=Geometry.calculate_job(model.snapshot(),317,0,1200,10)
 var apex=600.0-200.0+400.0/3.0
 var found=false
 for s in result.stations:
  if abs(s-apex)<1e-7:found=true
 assert(found)
 save_fixture("profile-dxf-asymmetric.dxf",result)
 model.pvi_heights=PackedFloat64Array([-20,-10,-20])
 model.offset=0
 assert(model.rebuild_alignment()=="")
 result=Geometry.calculate_job(model.snapshot(),20,0,1200,5)
 assert(result.datum==-20)
 save_fixture("profile-dxf-negative.dxf",result)
 for args in [[0,0,100,10],[20,-1,100,10],[20,100,50,10],[20,0,1201,10],[20,0,0.5,10],[20,0,100,0],[20,0,100,101],[NAN,0,100,10]]:assert(not Geometry.calculate_job(model.snapshot(),args[0],args[1],args[2],args[3]).ok)
 print("PROFILE DXF FIXTURES "+ProjectSettings.globalize_path("user://"))
 print("PASS PROFILE DXF CORE: native parabola/offset, selected endpoints/events, integer interval handling, scale, ground-only gaps, negative datum and invalid ranges")
 quit(0)
