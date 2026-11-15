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
 var off=Dxf.calculate_job(model.snapshot(),25,30,1,3)
 var result=Dxf.calculate_job(model.snapshot(),25,30,1,3,{},"",false,5)
 assert(result.ok and result.grid_step==5 and result.grid_lines==60)
 assert(model.edit_state()==before and result.sections==off.sections and result.samples==off.samples)
 save("section-grid-analytic.dxf",result)
 save("section-grid-off.dxf",off)
 assert(off.text==Dxf.calculate_job(model.snapshot(),25,30,1,3,{},"",false,0).text)
 model.pvi_heights=PackedFloat64Array([-2,-2])
 assert(model.rebuild_alignment()=="")
 save("section-grid-negative.dxf",Dxf.calculate_job(model.snapshot(),25,30,1,3,{},"",false,5))
 save("section-grid-dense.dxf",Dxf.calculate_job(model.snapshot(),25,30,1,3,{},"",false,0.5))
 save("section-grid-coarse.dxf",Dxf.calculate_job(model.snapshot(),25,30,1,3,{},"",false,1000))
 for invalid in [-1,0.1,1001,NAN,INF]:assert(not Dxf.calculate_job(model.snapshot(),25,30,1,3,{},"",false,invalid).ok)
 assert(not Dxf.calculate_job(model.snapshot(),100,10000,50,3,{},"",false,0.5).ok)
 assert(not Dxf.calculate_job(model.snapshot(),1,100,2,3,{},"",false,0.5).ok)
 save("section-grid-combined.dxf",Dxf.calculate_job(model.snapshot(),100,30,1,3,{"begin":10,"end":90},"12.25",true,5))
 print("SECTION GRID FIXTURES "+ProjectSettings.globalize_path("user://"))
 print("PASS SECTION GRID CORE: optional grid, immutable traces/sections, negative DATUM, dense/coarse spacing, input validation, grid budgets and range/extra/boundary combination")
 quit(0)
