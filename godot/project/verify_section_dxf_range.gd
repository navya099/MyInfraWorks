extends SceneTree
const Model=preload("res://scripts/road_model.gd")
const Dxf=preload("res://scripts/section_dxf_geometry.gd")
func save(name,result):
 assert(result.ok,str(result))
 var file=FileAccess.open("user://"+name,FileAccess.WRITE)
 assert(file!=null)
 file.store_string(result.text)
 file.close()
func _initialize():
 var heights=PackedFloat64Array()
 heights.resize(201*201)
 heights.fill(0)
 var terrain={"Nx":201,"Ny":201,"Dx":1.0,"Dy":1.0,"Min":0.0,"Max":0.0,"Heights":heights}
 var model=Model.new()
 model.terrain=terrain
 model.source=terrain
 model.route=PackedVector3Array([Vector3(50,2,100),Vector3(150,2,100)])
 model.left_fall=2
 model.right_fall=4
 assert(model.rebuild_alignment()=="")
 var before=model.edit_state()
 var bounds={"begin":12.25,"end":87.75}
 var result=Dxf.calculate_job(model.snapshot(),25,30,1,3,bounds)
 assert(result.ok and result.sections.size()==5 and result.samples==305 and result.missing==0)
 assert(result.sections[0].station==12.25 and result.sections[1].station==25 and result.sections[-1].station==87.75)
 assert(model.edit_state()==before)
 save("section-range-analytic.dxf",result)
 save("section-range-full.dxf",Dxf.calculate_job(model.snapshot(),25,30,1,3))
 save("section-range-explicit-full.dxf",Dxf.calculate_job(model.snapshot(),25,30,1,3,{"begin":0,"end":100}))
 save("section-range-near.dxf",Dxf.calculate_job(model.snapshot(),25,30,1,3,{"begin":24.99999999,"end":75.00000001}))
 for bounds_bad in [{"begin":-1,"end":50},{"begin":0,"end":101},{"begin":50,"end":40},{"begin":50,"end":50.5},{"begin":NAN,"end":100},{"begin":0,"end":INF}]:
  assert(not Dxf.calculate_job(model.snapshot(),25,30,1,3,bounds_bad).ok)
 var hole=terrain.duplicate(true)
 var missing=heights.duplicate()
 for x in range(201):missing[100*201+x]=NAN
 hole.Heights=missing
 model.source=hole
 result=Dxf.calculate_job(model.snapshot(),25,30,1,3,bounds)
 assert(result.ok and result.missing>0)
 for section in result.sections:assert(section.ground_runs==2 and section.design_runs==2)
 save("section-range-gap.dxf",result)
 missing.fill(NAN)
 hole.Heights=missing
 save("section-range-empty.dxf",Dxf.calculate_job(model.snapshot(),25,30,1,3,bounds))
 model.source=terrain
 model.route=PackedVector3Array([Vector3(50,2,100),Vector3(100050,2,100)])
 model.pvi_stations=PackedFloat64Array()
 assert(model.rebuild_alignment()=="")
 assert(not Dxf.calculate_job(model.snapshot(),1,30,1,3).ok)
 result=Dxf.calculate_job(model.snapshot(),1,30,1,3,{"begin":50000,"end":50010})
 assert(result.ok and result.sections.size()==11 and result.samples==671)
 save("section-range-long-subset.dxf",result)
 assert(Dxf.calculate_job(model.snapshot(),1,5,50,3,{"begin":50000,"end":50499}).sections.size()==500)
 assert(not Dxf.calculate_job(model.snapshot(),1,5,50,3,{"begin":50000,"end":50500}).ok)
 assert(Dxf.calculate_job(model.snapshot(),1,5,50,3,{"begin":50000,"end":50001}).ok)
 assert(not Dxf.calculate_job(model.snapshot(),1,1000,1,3,{"begin":50000,"end":50100}).ok)
 print("SECTION RANGE FIXTURES "+ProjectSettings.globalize_path("user://"))
 print("PASS SECTION RANGE CORE: exact/global stations, immutable input, full compatibility, gaps/empty, minimum/invalid ranges and subset section/sample budgets")
 quit(0)
