extends SceneTree
const Diagram=preload("res://scripts/mass_haul.gd")
const Earthwork=preload("res://scripts/earthwork_report.gd")
const Model=preload("res://scripts/road_model.gd")
func _initialize():
 var sections=[{"station":0.0},{"station":10.0,"interval_status":"included","cut_volume":30.0,"fill_volume":10.0},{"station":20.0,"interval_status":"included","cut_volume":5.0,"fill_volume":25.0},{"station":30.0,"interval_status":"excluded","cut_volume":null,"fill_volume":null},{"station":40.0,"interval_status":"included","cut_volume":0.0,"fill_volume":50.0}]
 var data=Diagram.build_data(sections)
 assert(data.segments.size()==2 and data.gaps==[Vector2(20,30)])
 assert(data.segments[0]==[Vector2(0,0),Vector2(10,20),Vector2(20,0)])
 assert(data.segments[1]==[Vector2(30,0),Vector2(40,-50)])
 assert(data.rows[3].kind=="excluded" and data.rows[3].net==null and data.rows[4].kind=="segment_start" and data.rows[4].station==30 and data.rows[4].net==0)
 assert(data.low==-50 and data.high==20)
 assert(Diagram.build_data([]).segments.is_empty())
 assert(Diagram.build_data([{"station":0},{"station":10,"interval_status":"excluded","cut_volume":null,"fill_volume":null}]).segments.is_empty())
 var heights=PackedFloat64Array()
 heights.resize(201*201)
 heights.fill(0)
 var terrain={"Nx":201,"Ny":201,"Dx":1.0,"Dy":1.0,"Min":0.0,"Max":0.0,"Heights":heights}
 var model=Model.new()
 model.terrain=terrain
 model.source=terrain
 model.route=PackedVector3Array([Vector3(50,2,100),Vector3(150,2,100)])
 assert(model.rebuild_alignment()=="")
 var report=Earthwork.calculate_job(model.snapshot(),25,30,1)
 data=Diagram.build_data(report.sections)
 assert(data.segments.size()==1 and abs(data.segments[0][-1].y+4600)<1e-6)
 var hole=terrain.duplicate(true)
 for y in range(201):heights[y*201+100]=NAN
 hole.Heights=heights
 model.source=hole
 report=Earthwork.calculate_job(model.snapshot(),25,30,1)
 data=Diagram.build_data(report.sections)
 assert(data.segments.size()==2 and data.gaps.size()==2)
 assert(abs(data.segments[0][-1].y+1150)<1e-6 and abs(data.segments[1][-1].y+1150)<1e-6)
 assert(data.segments[1][0]==Vector2(75,0))
 print("PASS MASS HAUL CORE: analytic balance, segment restart, excluded/null vs zero and native DEM gaps")
 quit(0)
