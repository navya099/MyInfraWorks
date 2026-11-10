extends SceneTree
var failures=[]
func check(condition,label):
 print(("PASS " if condition else "FAIL ")+label)
 if not condition:
  failures.append(label)

func _initialize():
 var core=ClassDB.instantiate("KRoadCore")
 var coarse=PackedFloat64Array()
 coarse.resize(33*33)
 coarse.fill(100)
 var fine=PackedFloat32Array()
 fine.resize(129*129)
 fine.fill(100)
 fine[51*129+51]=300
 var t={"Nx":33,"Ny":33,"Dx":60.0,"Dy":60.0,"Heights":coarse,"Min":100.0,"Max":300.0}
 var source={"Nx":129,"Ny":129,"Dx":15.0,"Dy":15.0,"Heights":fine}
 check(core.sample_height(source,765,765)==300,"float32 source ridge height")
 check(core.sample_height(t,765,765)==100,"preview misses ridge by design")
 var stats=core.grid_stats(source)
 check(stats.Min==100 and stats.Max==300,"native source extrema")
 var model=load("res://scripts/road_model.gd").new()
 check(model.set_terrain(t,source)=="","aligned source attached")
 check(model.ground(765,765)==300,"model profile uses source, not preview")
 # Flat data keeps the refinement footprint small enough to exercise transitions.
 fine[51*129+51]=100
 source.Heights=fine
 t.Max=100
 var route=PackedVector3Array([Vector3(100,110,200),Vector3(1800,110,200)])
 var a=core.build_render_tile(t,source,route,0,0,16,20,0,1.5,4)
 var b=core.build_render_tile(t,source,route,16,0,16,20,0,1.5,4)
 check(a.refined_cells>0 and a.refined_cells<256,"only corridor cells refined")
 check(a.vertices.size()>17*17 and a.vertices.size()<65*65,"adaptive mesh has bounded local detail")
 var left={}
 var right={}
 for i in range(a.vertices.size()):
  if abs(a.vertices[i].x)<0.001:
   left[snapped(a.vertices[i].z,0.001)]=[a.vertices[i],a.normals[i]]
 for i in range(b.vertices.size()):
  if abs(b.vertices[i].x)<0.001:
   right[snapped(b.vertices[i].z,0.001)]=[b.vertices[i],b.normals[i]]
 var shared=left.size()==right.size() and not left.is_empty()
 for key in left:
  shared=shared and right.has(key)
  if right.has(key):
   shared=shared and left[key][0].is_equal_approx(right[key][0]) and left[key][1].is_equal_approx(right[key][1])
 check(shared,"adaptive tile boundaries match positions and normals")
 # Every interior mesh edge must be shared by two triangles: no T-junction cracks.
 var edges={}
 for i in range(0,a.indices.size(),3):
  for j in range(3):
   var one=a.indices[i+j]
   var two=a.indices[i+(j+1)%3]
   var key=Vector2i(min(one,two),max(one,two))
   edges[key]=edges.get(key,0)+1
 var manifold=true
 for key in edges:
  if edges[key]==2:
   continue
  var p=a.vertices[key.x]
  var q=a.vertices[key.y]
  var boundary=(abs(p.x+960)<0.001 and abs(q.x+960)<0.001) or (abs(p.x)<0.001 and abs(q.x)<0.001) or (abs(p.z+960)<0.001 and abs(q.z+960)<0.001) or (abs(p.z)<0.001 and abs(q.z)<0.001)
  if edges[key]!=1 or not boundary:
   manifold=false
 check(manifold,"coarse-to-fine transition has no open interior edges")
 var restored=core.build_render_tile(t,source,PackedVector3Array(),0,0,16,20,0,1.5,4)
 check(restored.refined_cells==0 and restored.vertices.size()==17*17,"cleared corridor returns to coarse mesh")
 var all_ground=true
 for point in restored.vertices:
  all_ground=all_ground and abs(point.y)<0.001
 check(all_ground,"cleared corridor restores original height")
 var invalid=source.duplicate()
 invalid.Nx=4
 check(model.set_terrain(t,invalid)!="","mismatched source grid rejected")
 # Legacy JSON projects remain readable; they only contain preview-resolution data.
 var editor=load("res://scripts/editor.gd")
 var legacy={"version":1,"terrain":{"Nx":2,"Ny":2,"Dx":10.0,"Dy":10.0,"Heights":[100,100,100,100]},"route":[],"width":20,"offset":0,"slope":1.5}
 var file=FileAccess.open("user://legacy_fixture.kroadg",FileAccess.WRITE)
 file.store_string(JSON.stringify(legacy))
 file.close()
 var old=editor.read_document("user://legacy_fixture.kroadg",true)
 check(not old.has("error") and old.document.version==1,"v1 JSON project reader remains compatible")
 var invalid_origin=source.duplicate()
 invalid_origin.OriginX=20
 invalid_origin.OriginY=0
 var shifted=t.duplicate()
 shifted.OriginX=0
 shifted.OriginY=0
 check(model.set_terrain(shifted,invalid_origin)!="","misaligned source origin rejected")
 print("PASS DETAIL CORE" if failures.is_empty() else "FAIL DETAIL CORE")
 quit(0 if failures.is_empty() else 1)
