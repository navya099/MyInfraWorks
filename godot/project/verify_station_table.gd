extends SceneTree
const Model=preload("res://scripts/road_model.gd")
const Table=preload("res://scripts/station_table.gd")
var failures=0
func check(value,label):
 if value:print("PASS "+label)
 else:
  failures+=1
  push_error("FAIL "+label)

func _initialize():
 var model=Model.new()
 model.demo()
 model.route=PackedVector3Array([Vector3(600,0,1000),Vector3(1600,0,1000)])
 model.pvi_stations=PackedFloat64Array([0,500,1000])
 model.pvi_heights=PackedFloat64Array([100,150,100])
 model.pvi_lengths=PackedFloat64Array([0,200,0])
 model.left_fall=2
 model.right_fall=4
 model.offset=3
 assert(model.rebuild_alignment()=="")
 model.source.OriginX=1000000.0
 model.source.OriginY=2000000.0
 var report=Table.calculate_job(model.snapshot(),300)
 check(report.ok and report.rows.size()==7,"regular stations merged with exact endpoints/PVI/vertical boundaries")
 var expected=[0,300,400,500,600,900,1000]
 for i in range(expected.size()):check(abs(report.rows[i].station-expected[i])<1e-8,"exact station "+str(expected[i]))
 var row=report.rows[3]
 check(abs(row.planned-148)<1e-8 and abs(row.grade)<1e-8,"parabolic crest is sampled rather than PVI control height")
 check(abs(row.left_edge-147.8)<1e-8 and abs(row.right_edge-147.6)<1e-8,"crossfall and offset included in edge heights")
 check(row.radius==null and row.curvature==0,"straight radius is undefined, not zero")
 check(abs(row.x-1100)<1e-8 and abs(row.y-1000)<1e-8 and abs(row.easting-1001100)<1e-8 and abs(row.northing-1999000)<1e-8,"local east/south and EPSG east/north signs")
 check(abs(row.ground-model.ground(row.x,row.y))<1e-8 and abs(row.delta-(row.planned-row.ground))<1e-8,"source ground and signed difference")
 check("vertical_curve_end" in report.rows[4].events and "regular" in report.rows[4].events,"coincident events retained")
 model.source.erase("OriginX")
 model.source.erase("OriginY")
 report=Table.calculate_job(model.snapshot(),300)
 check(report.crs=="LOCAL" and report.rows[0].easting==null and report.rows[0].northing==null,"unreferenced terrain never invents projected coordinates")
 var source=model.source.duplicate(true)
 var h=source.Heights.duplicate()
 h.fill(NAN)
 source.Heights=h
 var state=model.snapshot()
 state.source=source
 report=Table.calculate_job(state,300)
 check(report.ok and report.missing==report.rows.size() and report.rows[0].ground==null and report.rows[0].delta==null and is_finite(report.rows[0].planned),"NoData keeps valid planned rows with missing ground/difference")
 check(not Table.calculate_job(state,NAN).ok and not Table.calculate_job(state,0).ok,"invalid station interval rejected")
 check(not Table.calculate_job(state,0.01).ok,"interval outside range rejected")
 # Curved route: boundary stations and local radius agree with native geometry.
 model.route=PackedVector3Array([Vector3(300,0,3300),Vector3(2700,0,3300),Vector3(2700,0,600)])
 model.pvi_stations=PackedFloat64Array()
 model.radii=PackedFloat64Array([0,300,0])
 model.spirals=PackedFloat64Array([0,50,0])
 assert(model.rebuild_alignment()=="")
 report=Table.calculate_job(model.snapshot(),700)
 var curved=false
 for r in report.rows:
  if r.radius!=null and abs(r.radius-300)<1e-5:curved=true
 check(curved,"curved PI station yields analytic circle radius")
 check(not Table.calculate_job(model.snapshot(),0.1).ok,"20k row budget rejects oversized export")
 if failures==0:print("PASS STATION TABLE CORE")
 quit(0 if failures==0 else 1)
