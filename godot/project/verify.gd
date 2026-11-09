extends SceneTree
var failures=[]
func check(condition,label):
 if not condition:
  failures.append(label)
  push_error(label)
 else:
  print("PASS ",label)

func _initialize():
 if not ClassDB.class_exists("KRoadCore"):
  push_error("KRoadCore extension not loaded")
  quit(1)
  return
 var core=ClassDB.instantiate("KRoadCore")
 check(abs(core.interpolate_elevation(100,200,0.25)-125)<0.000001,"elevation interpolation")
 var heights=PackedFloat64Array()
 heights.resize(25)
 heights.fill(100.0)
 var t={"Nx":5,"Ny":5,"Dx":10.0,"Dy":10.0,"Heights":heights,"Min":100.0,"Max":100.0}
 check(core.sample_height(t,5,5)==100.0,"bilinear height")
 check(is_nan(core.sample_height(t,-1,0)),"outside terrain rejected")
 check(is_nan(core.sample_height({},0,0)),"malformed terrain rejected")
 var route=PackedVector3Array([Vector3(0,110,20),Vector3(40,110,20)])
 check(core.design_height(t,route,20,20,4,0,2)==110.0,"fill platform")
 check(core.design_height(t,route,20,28,4,0,2)==107.0,"fill slope H:V")
 var left=core.build_tile(t,route,0,0,2,4,0,2)
 var right=core.build_tile(t,route,2,0,2,4,0,2)
 check(left.vertices.size()==9 and left.indices.size()==24,"tile vertex and triangle counts")
 var same=true
 for y in range(3):
  same=same and left.vertices[y*3+2].is_equal_approx(right.vertices[y*3])
  same=same and left.normals[y*3+2].is_equal_approx(right.normals[y*3])
 check(same,"tile boundary positions and normals")
 check(left.normals[0].y>0,"upward normals")
 route=PackedVector3Array([Vector3(0,90,20),Vector3(40,90,20)])
 check(core.design_height(t,route,20,20,4,0,2)==90.0,"cut platform")
 check(core.design_height(t,route,20,28,4,0,2)==93.0,"cut slope H:V")
 check(core.design_height(t,PackedVector3Array(),20,20,4,0,2)==100.0,"clear route restores ground")
 heights[0]=NAN
 t.Heights=heights
 check(is_nan(core.sample_height(t,1,1)),"NoData propagation")
 var hole=core.build_tile(t,PackedVector3Array(),0,0,2,4,0,2)
 check(hole.indices.size()==18,"NoData cell triangles omitted")
 var finite_colors=true
 for color in hole.colors:
  finite_colors=finite_colors and is_finite(color.r) and is_finite(color.g) and is_finite(color.b)
 check(finite_colors,"NoData mesh colors stay finite")
 check(core.build_tile(t,route,6,0,2,4,0,2).is_empty(),"out of bounds tile rejected")
 var large=PackedFloat64Array()
 large.resize(513*513)
 large.fill(100)
 var terrain={"Nx":513,"Ny":513,"Dx":30.0,"Dy":30.0,"Heights":large,"Min":100.0,"Max":100.0}
 var start=Time.get_ticks_usec()
 var vertices=0
 for y in range(0,512,32):
  for x in range(0,512,32):
   var mesh=core.build_tile(terrain,route,x,y,32,20,0,1.5)
   vertices+=mesh.vertices.size()
 print("BENCH C++: 513x513 / 256 tiles / %d vertices / %.2f ms" % [vertices,(Time.get_ticks_usec()-start)/1000.0])
 print("PASS NATIVE CORE" if failures.is_empty() else "FAIL NATIVE CORE")
 quit(0 if failures.is_empty() else 1)
