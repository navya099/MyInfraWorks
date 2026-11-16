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
 var snap=model.snapshot()
 var normal=Dxf.calculate_job(snap,25,30,1,3)
 assert(normal.text==Dxf.calculate_job(snap,25,30,1,3,{},"",false,0,false).text)
 var single=Dxf.calculate_job(snap,25,30,1,3,{},"37.25",true,5,true)
 assert(single.ok and single.sections.size()==1 and single.sections[0].station==37.25)
 assert(not single.include_boundaries and single.boundary_sections==0 and single.extras_only)
 save("section-selected-single.dxf",single)
 var rounded=Dxf.calculate_job(snap,25,30,1,3,{},"37.25",false,0,true,true,1)
 assert(rounded.ok and "STA 0+037.3 |" in rounded.text and rounded.sections==single.sections)
 assert(not Dxf.calculate_job(snap,25,30,1,3,{},"",false,0,false,false,4).ok)
 var many=Dxf.calculate_job(snap,25,30,1,2,{},"87.75, 12.25, 50, 50",true,0,true)
 assert(many.ok and many.extra_requested==4 and many.sections.size()==3)
 assert(many.sections.map(func(v):return v.station)==[12.25,50.0,87.75])
 save("section-selected-many.dxf",many)
 var ends=Dxf.calculate_job(snap,25,30,1,3,{},"100,0",false,0,true)
 assert(ends.ok and ends.sections.size()==2 and ends.sections[0].station==0 and ends.sections[1].station==100)
 save("section-selected-ends.dxf",ends)
 for invalid in ["", " ", "-1", "101", "nan", "1,", "12,99"]:
  assert(not Dxf.calculate_job(snap,25,30,1,3,{"begin":10,"end":90},invalid,false,0,true).ok,invalid)
 var limited=Dxf.calculate_job(snap,25,30,1,3,{"begin":10,"end":90},"12.25,87.75",true,5,true)
 assert(limited.ok and limited.sections.size()==2)
 assert(model.edit_state()==before)
 model.route=PackedVector3Array([Vector3(50,2,100),Vector3(100050,2,100)])
 assert(model.rebuild_alignment()=="")
 assert(not Dxf.calculate_job(model.snapshot(),1,30,1,3).ok)
 var long_result=Dxf.calculate_job(model.snapshot(),1,30,1,3,{},"50000",true,0,true)
 assert(long_result.ok and long_result.sections.size()==1)
 var entries=[]
 for i in range(100):entries.append(str(i))
 assert(not Dxf.calculate_job(model.snapshot(),1,1000,1,3,{},",".join(entries),false,0,true).ok)
 print("PASS SECTION SELECTED CORE: single/multiple/endpoints, sorting/duplicates, range/empty rejection, no automatic stations, long route, sample budget and unchanged default")
 quit(0)
