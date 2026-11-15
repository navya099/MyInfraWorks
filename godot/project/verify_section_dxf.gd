extends SceneTree
const Model=preload("res://scripts/road_model.gd")
const Geometry=preload("res://scripts/section_dxf_geometry.gd")
func save_fixture(name,result):
 assert(result.ok)
 var file=FileAccess.open("user://"+name,FileAccess.WRITE)
 assert(file!=null)
 file.store_string(result.text)
 file.close()
func _initialize():
 var values=PackedFloat64Array()
 values.resize(201*201)
 values.fill(0)
 var terrain={"Nx":201,"Ny":201,"Dx":1.0,"Dy":1.0,"Min":0.0,"Max":0.0,"Heights":values}
 var model=Model.new()
 model.terrain=terrain
 model.source=terrain
 model.route=PackedVector3Array([Vector3(50,2,100),Vector3(150,2,100)])
 model.left_fall=2
 model.right_fall=4
 assert(model.rebuild_alignment()=="")
 var before=model.edit_state()
 var result=Geometry.calculate_job(model.snapshot(),25,30,1,3)
 assert(result.ok and result.sections.size()==5 and result.samples==305 and result.sections[-1].station==100 and result.missing==0)
 assert(model.edit_state()==before)
 save_fixture("section-dxf-analytic.dxf",result)
 var hole=terrain.duplicate(true)
 var missing=values.duplicate()
 for x in range(201):missing[100*201+x]=NAN
 hole.Heights=missing
 model.source=hole
 result=Geometry.calculate_job(model.snapshot(),25,30,1,3)
 assert(result.ok and result.missing>0)
 for section in result.sections:assert(section.ground_runs==2 and section.design_runs==2)
 save_fixture("section-dxf-gap.dxf",result)
 missing.fill(NAN)
 hole.Heights=missing
 result=Geometry.calculate_job(model.snapshot(),25,30,1,3)
 for section in result.sections:assert(section.ground_runs==0 and section.design_runs==0)
 save_fixture("section-dxf-empty.dxf",result)
 for y in [105,106]:
  for x in [100,101]:missing[y*201+x]=0
 hole.Heights=missing
 result=Geometry.calculate_job(model.snapshot(),25,30,1,3)
 assert(result.sections[2].ground_runs==1 and result.sections[2].ground_missing==60)
 save_fixture("section-dxf-point.dxf",result)
 model.source=terrain
 model.pvi_heights=PackedFloat64Array([-2,-2])
 model.cut_slope=0.5
 assert(model.rebuild_alignment()=="")
 result=Geometry.calculate_job(model.snapshot(),40,30,1,2)
 assert(result.sections.size()==4 and result.sections[-1].station==100)
 save_fixture("section-dxf-cut.dxf",result)
 assert(not Geometry.calculate_job(model.snapshot(),0,30,1,3).ok)
 assert(not Geometry.calculate_job(model.snapshot(),25,30,1,2.5).ok)
 assert(not Geometry.calculate_job(model.snapshot(),25,10000,0.1,3).ok)
 var big=model.snapshot()
 big.pi_route[-1].x=10050
 assert(not Geometry.calculate_job(big,1,30,1,3).ok)
 assert(not Geometry.calculate_job(big,100,1000,1,3).ok)
 print("SECTION DXF FIXTURES "+ProjectSettings.globalize_path("user://"))
 print("PASS SECTION DXF CORE: fixed stations/end, source preservation, separate traces, gaps/isolated points, negative datum, remainder and budgets")
 quit(0)
