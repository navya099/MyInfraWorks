extends SceneTree
const Blocks=preload("res://scripts/earthwork_blocks.gd")
const RangeCalculation=preload("res://scripts/earthwork_range.gd")
const Model=preload("res://scripts/road_model.gd")
const Earthwork=preload("res://scripts/earthwork_report.gd")
func conserve(report,begin,finish,step):
 var result=Blocks.calculate(report,begin,finish,step)
 assert(result.ok)
 var full=RangeCalculation.calculate(report,begin,finish)
 var cut=0.0
 var fill=0.0
 var length=0.0
 var covered=0.0
 var previous=begin
 for row in result.rows:
  assert(row.start==previous and row.end>row.start)
  if row.cut!=null:cut+=row.cut
  if row.fill!=null:fill+=row.fill
  covered+=row.covered
  length+=row.length
  previous=row.end
 assert(previous==finish and abs(length-full.length)<1e-7 and abs(covered-full.covered)<1e-7)
 assert(abs(cut-full.get("cut",0))<1e-6 and abs(fill-full.get("fill",0))<1e-6)
 return result
func _initialize():
 var report={"ok":true,"sections":[{"station":0.0,"status":"ok","cut_area":10.0,"fill_area":20.0},{"station":100.0,"status":"ok","interval_status":"included","cut_area":30.0,"fill_area":0.0}]}
 var result=conserve(report,0,100,30)

 assert(result.rows.size()==4 and abs(result.rows[0].cut-390)<1e-8 and abs(result.rows[0].fill-510)<1e-8 and result.rows[-1].length==10 and result.rows[-1].index==4)
 result=conserve(report,12.345,98.765,17.321)
 assert(result.rows[0].start==12.345 and result.rows[-1].end==98.765)
 assert(Blocks.calculate(report,0,3.3000000000000003,1.1).rows.size()==3)
 assert(Blocks.calculate(report,0,30,1000).rows.size()==1)
 report.sections.append_array([{"station":120.0,"status":"nodata","interval_status":"excluded"},{"station":150.0,"status":"ok","interval_status":"excluded","cut_area":0.0,"fill_area":0.0},{"station":200.0,"status":"ok","interval_status":"included","cut_area":0.0,"fill_area":0.0}])
 result=conserve(report,0,200,50)
 assert(result.counts.complete==3 and result.counts.missing==1 and result.rows[2].cut==null and result.rows[2].fill==null and result.rows[3].cut==0)
 result=conserve(report,0,200,60)
 assert(result.counts.partial==2 and result.covered==150 and result.excluded==2)
 var missing=Blocks.calculate(report,105,145,10)
 assert(missing.status=="missing" and missing.cut==null and missing.rows[0].cut==null)
 for step in [0,-1,NAN,INF,1000001]:assert(not Blocks.calculate(report,0,100,step).ok)
 for bounds in [[0,0],[50,20],[-1,20],[0,201],[NAN,100],[0,INF]]:assert(not Blocks.calculate(report,bounds[0],bounds[1],10).ok)
 var large=report.duplicate(true)
 large.sections=[report.sections[0],report.sections[1].duplicate()]
 large.sections[1].station=100000
 assert(Blocks.calculate(large,0,100000,100).rows.size()==1000)
 assert(not Blocks.calculate(large,0,100000,99).ok)
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
 result=conserve(report,0,100,17)
 assert(abs(result.fill-4600)<1e-6)
 var hole=terrain.duplicate(true)
 var values=heights.duplicate()
 for y in range(201):values[y*201+100]=NAN
 hole.Heights=values
 model.source=hole
 report=Earthwork.calculate_job(model.snapshot(),25,30,1)
 result=conserve(report,0,100,10)
 assert(result.counts.missing>0 and result.covered==50 and result.fill==2300)
 print("PASS EARTHWORK BLOCKS CORE: analytic partitions, conservation, remainder, offset origin, decimal boundary, null vs zero, native gaps and 1000-block budget")
 quit(0)
