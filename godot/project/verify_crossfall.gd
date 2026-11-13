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
 check(core.set_crossfall(2,4),"asymmetric crossfall accepted")
 check(abs(core.design_height(grid,route,100,90,20,0,1.5)-1.8)<1e-8,"forward left edge -2 percent")
 check(abs(core.design_height(grid,route,100,110,20,0,1.5)-1.6)<1e-8,"forward right edge -4 percent")
 check(abs(core.design_height(grid,route,100,100,20,0,1.5)-2)<1e-8,"centre elevation unchanged")
 check(abs(core.design_height(grid,route,100,111,20,0,1.5)-(1.6-1.0/1.5))<1e-8,"slope starts at lowered shoulder")
 core.prepare_corridor(route,20,0,1.5,0,0,2)
 check(abs(core.design_height(grid,route,100,90,20,0,1.5)-1.8)<1e-8,"indexed crown matches fallback")
 var poses=PackedFloat64Array([50,100,2,0,1,150,100,2,0,1])
 var report=core.earthwork_sections(grid,PackedFloat64Array([0,100]),poses,20,0,1.5,30,1)
 check(report.complete and abs(report.fill_volume-4135)<1e-6,"analytic crowned fill 41.35m2 / 4135m3")
 core.set_crossfall(2,4)
 var cut_poses=PackedFloat64Array([50,100,-2,0,1,150,100,-2,0,1])
 report=core.earthwork_sections(grid,PackedFloat64Array([0,100]),cut_poses,20,0,1.5,30,1)
 check(report.complete and abs(report.cut_volume-5095)<1e-6,"analytic crowned cut 50.95m2 / 5095m3")
 var reverse=PackedVector3Array([route[1],route[0]])
 core.prepare_corridor(reverse,20,0,1.5,0,0,2)
 check(abs(core.design_height(grid,reverse,100,90,20,0,1.5)-1.6)<1e-8,"reversed route swaps physical left/right")
 core.set_crossfall(-2,2)
 report=core.earthwork_sections(grid,PackedFloat64Array([0,100]),poses,20,0,1.5,30,1)
 check(abs(report.fill_volume-4606)<1e-6,"signed one-way tilt analytic quantity")
 check(not core.set_crossfall(NAN,0) and not core.set_crossfall(0,12.1),"invalid crossfall rejected atomically")
 check(abs(core.design_height(grid,route,100,90,20,0,1.5)-2.2)<1e-8,"rejected input preserves previous crossfall")
 var alignment=ClassDB.instantiate("KRoadAlignment")
 var result=alignment.configure_independent(route,PackedFloat64Array([0,0]),PackedFloat64Array([0,0]),PackedFloat64Array([0,100]),PackedFloat64Array([2,2]),PackedFloat64Array([0,0]))
 check(result.ok,"ribbon alignment configured")
 var mesh=alignment.ribbon_crossfall(20,0,0,0,0,2,4)
 check(mesh.vertices.size()%3==0 and abs(mesh.vertices[0].y-2.3)<1e-6 and abs(mesh.vertices[1].y-2.5)<1e-6 and abs(mesh.vertices[2].y-2.1)<1e-6,"three-vertex crown ribbon and existing 0.5m display lift")
 var all_up=true
 for i in range(0,mesh.indices.size(),3):
  var a=mesh.vertices[mesh.indices[i]]
  var b=mesh.vertices[mesh.indices[i+1]]
  var c=mesh.vertices[mesh.indices[i+2]]
  if (b-a).cross(c-a).y<=0:all_up=false
 check(all_up,"crown ribbon upward triangle winding")
 core.set_crossfall(0,0)
 report=core.earthwork_sections(grid,PackedFloat64Array([0,100]),poses,20,0,1.5,30,1)
 check(abs(report.fill_volume-4600)<1e-6,"zero crossfall retains legacy flat result")
 # Verify the actual editor worker pipeline, not just its direct native calls.
 core.set_crossfall(2,4)
 core.prepare_corridor(route,20,0,1.5,0,0,2)
 var editor=load("res://scripts/editor.gd")
 var state={"terrain":grid,"source":grid,"route":route,"width":20.0,"offset":0.0,"slope":1.5,"refinement":4,"left_fall":2.0,"right_fall":4.0}
 var job=editor.build_job(state,[Vector2i(2,3)])
 var tile=job.items[0].data
 var agrees=not tile.vertices.is_empty()
 for vertex in tile.vertices:
  var expected=core.design_height(grid,route,vertex.x+100,vertex.z+100,20,0,1.5)
  if abs(vertex.y-expected)>0.00001:agrees=false
 check(agrees,"editor background terrain worker uses the same crowned surface")
 var adjacent=editor.build_job(state,[Vector2i(3,3)]).items[0].data
 var boundary={}
 for i in range(tile.vertices.size()):
  if abs(tile.vertices[i].x+4)<0.00001:boundary[snapped(tile.vertices[i].z,0.00001)]=[tile.vertices[i],tile.normals[i]]
 var matches=0
 var seam=true
 for i in range(adjacent.vertices.size()):
  if abs(adjacent.vertices[i].x+4)<0.00001:
   matches+=1
   var key=snapped(adjacent.vertices[i].z,0.00001)
   if not boundary.has(key):seam=false
   elif not boundary[key][0].is_equal_approx(adjacent.vertices[i]) or not boundary[key][1].is_equal_approx(adjacent.normals[i]):seam=false
 check(seam and matches>0 and matches==boundary.size(),"crowned terrain tile positions and normals match at seam")
 # Conservative dirty coverage must include both raised/lowered shoulders.
 core.set_crossfall(12,-12)
 var affected=core.affected_tiles(grid,route,200,0,10,32)
 check(not affected.is_empty(),"extreme signed crossfall has dirty tile coverage")
 if failures==0:print("PASS CROSSFALL CORE")
 quit(0 if failures==0 else 1)
