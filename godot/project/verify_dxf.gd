extends SceneTree
const Model=preload("res://scripts/road_model.gd")
const Dxf=preload("res://scripts/dxf_geometry.gd")
var failures=0
func check(value,label):
 if value:print("PASS "+label)
 else:
  failures+=1
  push_error("FAIL "+label)
func save_text(path,text):
 var file=FileAccess.open(path,FileAccess.WRITE)
 file.store_string(text)
 file.close()
func _initialize():
 var model=Model.new()
 model.demo()
 model.route=PackedVector3Array([Vector3(100,100,200),Vector3(200,100,200)])
 model.offset=3
 model.left_fall=2
 model.right_fall=4
 assert(model.rebuild_alignment()=="")
 var report=Dxf.calculate_job(model.snapshot(),10,0)
 check(report.ok and report.vertices==report.stations*3 and report.stations>=11,"native sampling plus maximum spacing")
 check("AC1009" in report.text and "POLYLINE" in report.text and "SEQEND" in report.text,"R12 3D polyline structure")
 check("103.000000000" in report.text and "102.800000000" in report.text and "102.600000000" in report.text,"design and crossfall heights without display lift")
 save_text("user://dxf-local.dxf",report.text)
 check(not Dxf.calculate_job(model.snapshot(),10,1).ok,"projected mode rejected without georeference")
 model.source.OriginX=1000000.0
 model.source.OriginY=2000000.0
 report=Dxf.calculate_job(model.snapshot(),10,1)
 check(report.ok and "1000100.000000000" in report.text and "1999800.000000000" in report.text,"projected east/north coordinates")
 save_text("user://dxf-projected.dxf",report.text)
 model.route=PackedVector3Array([Vector3(100,100,900),Vector3(900,100,900),Vector3(900,100,100)])
 model.radii=PackedFloat64Array([0,300,0])
 model.spirals=PackedFloat64Array([0,0,0])
 assert(model.rebuild_alignment()=="")
 var stations=model.alignment.sampling_stations()
 check(stations[0]==0 and abs(stations[-1]-model.length())<1e-9,"sampling stations preserve exact endpoints")
 report=Dxf.calculate_job(model.snapshot(),10,0)
 check(report.ok and report.stations>ceili(model.length()/10),"curve adaptive stations retained")
 save_text("user://dxf-curve.dxf",report.text)
 model.route=PackedVector3Array([Vector3(100,100,200),Vector3(1100,100,200)])
 model.radii=PackedFloat64Array([0,0])
 model.spirals=PackedFloat64Array([0,0])
 model.pvi_stations=PackedFloat64Array([0,500,1000])
 model.pvi_heights=PackedFloat64Array([100,150,100])
 model.pvi_lengths=PackedFloat64Array([0,200,0])
 assert(model.rebuild_alignment()=="")
 report=Dxf.calculate_job(model.snapshot(),10,0)
 save_text("user://dxf-parabola.dxf",report.text)
 check(not Dxf.calculate_job(model.snapshot(),0,0).ok and not Dxf.calculate_job(model.snapshot(),NAN,0).ok,"invalid spacing rejected")
 check(not Dxf.calculate_job(model.snapshot(),10,9).ok,"unknown coordinate mode rejected")
 model.route=PackedVector3Array([Vector3(0,100,0),Vector3(100000,100,0)])
 model.radii=PackedFloat64Array([0,0])
 model.spirals=PackedFloat64Array([0,0])
 assert(model.rebuild_alignment()=="")
 check(not Dxf.calculate_job(model.snapshot(),1,0).ok,"station budget enforced")
 print("DXF FIXTURES: "+ProjectSettings.globalize_path("user://"))
 if failures==0:print("PASS DXF GEOMETRY")
 quit(0 if failures==0 else 1)
