extends SceneTree
var failures=0
func check(value,label):
 if value:print("PASS "+label)
 else:
  failures+=1
  push_error("FAIL "+label)

func _initialize():
 var core=ClassDB.instantiate("KRoadCore")
 var heights=PackedFloat64Array()
 heights.resize(201*201)
 heights.fill(0)
 var grid={"Nx":201,"Ny":201,"Dx":1.0,"Dy":1.0,"Heights":heights,"Min":0.0,"Max":0.0}
 var route=PackedVector3Array([Vector3(50,2,100),Vector3(150,2,100)])
 var stations=PackedFloat64Array([0,100])
 var poses=PackedFloat64Array([50,100,2,0,1,150,100,2,0,1])
 check(core.set_cut_slope(0.5),"independent cut ratio accepted")
 var report=core.earthwork_sections(grid,stations,poses,20,0,2,30,1)
 check(report.complete and abs(report.fill_volume-4800)<1e-6,"fill H:V 2 gives analytic 48m2 and 4800m3")
 check(report.cut_slope==0.5 and report.fill_slope==2,"quantity metadata identifies both ratios")
 check(abs(core.design_height(grid,route,100,112,20,0,2)-1)<1e-8,"fill slope uses fill ratio")
 route[0].y=-2
 route[1].y=-2
 poses=PackedFloat64Array([50,100,-2,0,1,150,100,-2,0,1])
 report=core.earthwork_sections(grid,stations,poses,20,0,2,30,1)
 check(report.complete and abs(report.cut_volume-4200)<1e-6,"cut H:V 0.5 gives analytic 42m2 and 4200m3")
 check(abs(core.design_height(grid,route,100,110.5,20,0,2)+1)<1e-8,"cut slope uses cut ratio")
 core.prepare_corridor(route,20,0,2,0,0,2)
 check(abs(core.design_height(grid,route,100,110.5,20,0,2)+1)<1e-8,"indexed cut slope agrees with direct surface")
 report=core.earthwork_sections(grid,stations,poses,20,0,2,30,1)
 check(abs(report.cut_volume-4200)<1e-6,"indexed quantities agree with analytic cut")
 check(not core.set_cut_slope(0) and not core.set_cut_slope(NAN) and not core.set_cut_slope(101),"bad ratios rejected without changing current ratio")
 core.set_crossfall(2,4)
 report=core.earthwork_sections(grid,stations,poses,20,0,2,30,1)
 check(abs(report.cut_volume-4565)<1e-6,"crossfall plus independent cut slope analytic volume")
 poses=PackedFloat64Array([50,100,2,0,1,150,100,2,0,1])
 report=core.earthwork_sections(grid,stations,poses,20,0,2,30,1)
 check(abs(report.fill_volume-4280)<1e-6,"crossfall plus independent fill slope analytic volume")
 # Mixed cut/fill on a transverse planar ground: exact areas 100/9 and 50/3.
 for y in range(201):
  for x in range(201):heights[y*201+x]=0.2*(y-100)
 grid.Heights=heights
 grid.Min=-20
 grid.Max=20
 route=PackedVector3Array([Vector3(50,0,100),Vector3(150,0,100)])
 poses=PackedFloat64Array([50,100,0,0,1,150,100,0,0,1])
 core.set_crossfall(0,0)
 report=core.earthwork_sections(grid,stations,poses,20,0,2,30,1)
 check(report.complete and abs(report.sections[0].cut_area-100.0/9)<1e-6 and abs(report.sections[0].fill_area-50.0/3)<1e-6,"mixed section uses both daylight ratios independently")
 core.prepare_corridor(route,20,0,2,-20,20,2)
 var editor=load("res://scripts/editor.gd")
 var state={"terrain":grid,"source":grid,"route":route,"width":20.0,"offset":0.0,"slope":2.0,"cut_slope":0.5,"refinement":4,"left_fall":0.0,"right_fall":0.0}
 var tile=editor.build_job(state,[Vector2i(2,3)]).items[0].data
 var agrees=not tile.vertices.is_empty()
 for vertex in tile.vertices:
  var expected=core.design_height(grid,route,vertex.x+100,vertex.z+100,20,0,2)
  if abs(vertex.y+grid.Min-expected)>0.00001:agrees=false
 check(agrees,"editor terrain worker shares independent cut/fill surface")
 # API clients that do not configure a cut ratio preserve legacy shared behavior.
 var legacy=ClassDB.instantiate("KRoadCore")
 heights.fill(0)
 grid.Heights=heights
 poses=PackedFloat64Array([50,100,-2,0,1,150,100,-2,0,1])
 report=legacy.earthwork_sections(grid,stations,poses,20,0,2,30,1)
 check(abs(report.cut_volume-4800)<1e-6,"unconfigured native API retains shared legacy slope")
 # Cut flatter than fill must expand both spatial buckets and dirty tiles.
 var wide_cut=ClassDB.instantiate("KRoadCore")
 wide_cut.set_cut_slope(4)
 heights.fill(20)
 grid.Heights=heights
 grid.Min=20
 grid.Max=20
 route=PackedVector3Array([Vector3(50,0,100),Vector3(150,0,100)])
 wide_cut.prepare_corridor(route,20,0,0.5,20,20,2)
 check(abs(wide_cut.design_height(grid,route,100,170,20,0,0.5)-15)<1e-8,"wide cut is not omitted by narrow fill search bounds")
 check(wide_cut.affected_tiles(grid,route,20,0,0.5,32).has(Vector2(3,5)),"wide cut reaches its distant dirty tile")
 state={"terrain":grid,"source":grid,"route":route,"width":20.0,"offset":0.0,"slope":0.5,"cut_slope":4.0,"refinement":4,"left_fall":0.0,"right_fall":0.0}
 tile=editor.build_job(state,[Vector2i(3,5)]).items[0].data
 check(tile.refined_cells>0,"wide cut also expands adaptive render refinement")
 if failures==0:print("PASS CUT/FILL SLOPES CORE")
 quit(0 if failures==0 else 1)
