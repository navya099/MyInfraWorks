extends SceneTree
const RangeCalculation=preload("res://scripts/earthwork_range.gd")
const Earthwork=preload("res://scripts/earthwork_report.gd")
const Model=preload("res://scripts/road_model.gd")
func _initialize():
 var sections=[{"station":0.0,"status":"ok","cut_area":10.0,"fill_area":20.0},{"station":100.0,"status":"ok","interval_status":"included","cut_area":30.0,"fill_area":0.0}]
 var report={"ok":true,"sections":sections}
 var partial=RangeCalculation.calculate(report,20,60)
 assert(partial.ok and partial.status=="complete" and partial.cut==720 and partial.fill==480 and partial.net==240 and partial.coverage==1)
 assert(partial.rows[0].cut_start==14 and partial.rows[0].cut_end==22 and partial.rows[0].source_start==0 and partial.rows[0].source_end==100)
 var integers={"ok":true,"sections":[{"station":0,"status":"ok","cut_area":10,"fill_area":20},{"station":100,"status":"ok","interval_status":"included","cut_area":30,"fill_area":0}]}
 var integer_result=RangeCalculation.calculate(integers,20,60)
 assert(integer_result.cut==720 and integer_result.fill==480)
 var full=RangeCalculation.calculate(report,0,100)
 assert(full.cut==2000 and full.fill==1000)
 var a=RangeCalculation.calculate(report,0,30)
 var b=RangeCalculation.calculate(report,30,70)
 var c=RangeCalculation.calculate(report,70,100)
 assert(abs(a.cut+b.cut+c.cut-full.cut)<1e-9 and abs(a.fill+b.fill+c.fill-full.fill)<1e-9)
 sections.append({"station":120.0,"status":"nodata","interval_status":"excluded","cut_area":null,"fill_area":null})
 var mixed=RangeCalculation.calculate(report,90,110)
 assert(mixed.status=="partial" and mixed.covered==10 and mixed.coverage==0.5 and mixed.excluded==1 and mixed.rows[1].cut==null and mixed.rows[1].detail=="ok / nodata")
 var missing=RangeCalculation.calculate(report,100,110)
 assert(missing.status=="missing" and missing.cut==null and missing.fill==null and missing.net==null and missing.coverage==0)
 assert(RangeCalculation.calculate(report,0,100).status=="complete")
 for bounds in [[0,0],[50,20],[-1,20],[0,121],[NAN,100],[0,INF]]:assert(not RangeCalculation.calculate(report,bounds[0],bounds[1]).ok)
 assert(not RangeCalculation.calculate({},0,10).ok)
 var bad=report.duplicate(true)
 bad.sections[1].cut_area=NAN
 assert(not RangeCalculation.calculate(bad,0,100).ok)
 bad=report.duplicate(true)
 bad.sections[1].station=0
 assert(not RangeCalculation.calculate(bad,0,100).ok)
 var heights=PackedFloat64Array()
 heights.resize(201*201)
 heights.fill(0)
 var terrain={"Nx":201,"Ny":201,"Dx":1.0,"Dy":1.0,"Min":0.0,"Max":0.0,"Heights":heights}
 var model=Model.new()
 model.terrain=terrain
 model.source=terrain
 model.route=PackedVector3Array([Vector3(50,2,100),Vector3(150,2,100)])
 assert(model.rebuild_alignment()=="")
 report=Earthwork.calculate_job(model.snapshot(),25,30,1)
 full=RangeCalculation.calculate(report,0,100)
 assert(full.ok and full.cut==report.cut_volume and abs(full.fill-4600)<1e-6)
 partial=RangeCalculation.calculate(report,12.345,78.901)
 assert(abs(partial.fill-46*(78.901-12.345))<1e-6 and partial.coverage==1)
 var hole_heights=heights.duplicate()
 for y in range(201):hole_heights[y*201+100]=NAN
 var hole=terrain.duplicate(true)
 hole.Heights=hole_heights
 model.source=hole
 report=Earthwork.calculate_job(model.snapshot(),25,30,1)
 mixed=RangeCalculation.calculate(report,12.5,87.5)
 assert(mixed.status=="partial" and mixed.covered==25 and abs(mixed.fill-1150)<1e-6)
 assert(RangeCalculation.calculate(report,30,70).status=="missing")
 model.source=terrain
 model.pvi_heights=PackedFloat64Array([0,0])
 assert(model.rebuild_alignment()=="")
 report=Earthwork.calculate_job(model.snapshot(),25,30,1)
 var zero=RangeCalculation.calculate(report,0,100)
 assert(zero.status=="complete" and zero.cut==0 and zero.fill==0)
 print("PASS EARTHWORK RANGE CORE: analytic partial trapezoids, partition conservation, exact boundaries, null vs zero, native DEM gaps and input validation")
 quit(0)
