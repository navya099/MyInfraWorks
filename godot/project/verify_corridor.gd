extends SceneTree
var failures=[]
func check(condition,label):
 print(("PASS " if condition else "FAIL ")+label)
 if not condition: failures.append(label)
func brute(route,x,y):
 var best=INF
 var value=100.0
 for i in range(1,route.size()):
  var a=route[i-1]
  var b=route[i]
  var dx=b.x-a.x
  var dy=b.z-a.z
  var ll=dx*dx+dy*dy
  if ll<0.000001: continue
  var f=clamp(((x-a.x)*dx+(y-a.z)*dy)/ll,0.0,1.0)
  var ex=x-a.x-dx*f
  var ey=y-a.z-dy*f
  var d2=ex*ex+ey*ey
  if d2>=best: continue
  best=d2
  var road=a.y+(b.y-a.y)*f
  var side=max(0.0,sqrt(d2)-10)/1.5
  value=max(100,road-side) if road>100 else min(100,road+side)
 return value
func _initialize():
 var alignment=ClassDB.instantiate("KRoadAlignment")
 var p=PackedVector3Array([Vector3(5000,110,80000),Vector3(55000,145,80000),Vector3(55000,120,30000)])
 var result=alignment.configure(p,PackedFloat64Array([0,12000,0]),PackedFloat64Array([0,1000,0]),PackedFloat64Array([0,4000,0]))
 check(result.ok,"long S-C-S corridor configured")
 var route=alignment.polyline()
 var core=ClassDB.instantiate("KRoadCore")
 var terrain={"Nx":2,"Ny":2,"Dx":108000.0,"Dy":108000.0,"Min":100.0,"Max":100.0,"Heights":PackedFloat64Array([100,100,100,100])}
 core.prepare_corridor(route,20,0,1.5,100,100,450)
 var same=true
 for fraction in [0.0,0.02,0.10,0.25,0.48,0.50,0.52,0.75,0.90,0.98,1.0]:
  var at=alignment.sample(result.length*fraction)
  for offset in [-150.0,-25.0,0.0,25.0,150.0]:
   var x=at.x+at.normal.x*offset
   var y=at.y+at.normal.y*offset
   same=same and abs(core.design_height(terrain,route,x,y,20,0,1.5)-brute(route,x,y))<0.01
 check(same,"indexed nearest corridor matches independent all-segment search")
 var view=terrain.duplicate()
 view.Nx=513
 view.Ny=513
 view.Dx=108000.0/512
 view.Dy=108000.0/512
 var heights=PackedFloat64Array()
 heights.resize(513*513)
 heights.fill(100)
 view.Heights=heights
 var dirty={}
 for key in core.affected_tiles(view,route,20,0,1.5,32):dirty[Vector2i(key)]=true
 var covered=true
 for fraction in [0.0,0.1,0.2,0.4,0.5,0.6,0.8,1.0]:
  var at=alignment.sample(result.length*fraction)
  var tile=Vector2i(floor(at.x/(view.Dx*32)),floor(at.y/(view.Dy*32)))
  covered=covered and dirty.has(tile)
 check(covered,"dirty tile coverage follows curved centerline")
 var time=Time.get_ticks_usec()
 for i in range(20000):
  var at=alignment.sample(result.length*(i%1000)/999.0)
  core.design_height(terrain,route,at.x,at.y,20,0,1.5)
 print("BENCH INDEX: %d segments / 20000 sample+height queries %.2fms" % [route.size()-1,(Time.get_ticks_usec()-time)/1000.0])
 var ribbon=alignment.ribbon(20,0,100,54000,54000)
 check(ribbon.vertices.size()==route.size()*2 and ribbon.indices.size()==(route.size()-1)*6,"native road ribbon follows alignment tessellation")
 print("PASS CORRIDOR INDEX" if failures.is_empty() else "FAIL CORRIDOR INDEX")
 quit(0 if failures.is_empty() else 1)
