extends SceneTree
const Model=preload("res://scripts/road_model.gd")
const Comparison=preload("res://scripts/section_comparison.gd")
func _initialize():
 var heights=PackedFloat64Array()
 heights.resize(201*201)
 heights.fill(0)
 var terrain={"Nx":201,"Ny":201,"Dx":1.0,"Dy":1.0,"Min":0.0,"Max":0.0,"Heights":heights}
 var model=Model.new()
 model.terrain=terrain
 model.source=terrain
 model.route=PackedVector3Array([Vector3(50,2,100),Vector3(150,2,100)])
 model.left_fall=2
 model.right_fall=4
 assert(model.rebuild_alignment()=="")
 var saved=model.edit_state()
 model.offset=5
 assert(model.rebuild_alignment()=="")
 var current=model.edit_state()
 var state={"current":current,"saved":saved,"station":50.0,"terrain":terrain,"source":terrain,"name":'A, "횡단"'}
 var result=Comparison.calculate(state,3,30)
 assert(result.ok and result.rows[0].d==-30 and result.rows[-1].d==30 and result.missing==0)
 var centre=false
 var left=false
 var right=false
 for row in result.rows:
  assert(abs(row.x-100)<1e-8 and abs(row.y-(100+row.d))<1e-8 and row.ground==0)
  assert(abs(row.current-model.design(row.x,row.y))<1e-8)
  if row.d==0:
   assert(row.current==7 and row.saved==2 and row.delta==5 and row.current_ground==7 and row.saved_ground==2)
   centre=true
  elif row.d==-10:
   assert(abs(row.saved-1.8)<1e-8 and "current_left_edge" in row.events)
   left=true
  elif row.d==10:
   assert(abs(row.saved-1.6)<1e-8 and "current_right_edge" in row.events)
   right=true
 assert(centre and left and right)
 assert(model.edit_state()==current)
 var shifted=saved.duplicate(true)
 for i in range(shifted.pi_route.size()):shifted.pi_route[i].z+=20
 state.saved=shifted
 result=Comparison.calculate(state,1,40)
 for row in result.rows:
  if row.d==0:assert(row.saved==0)
  if row.d==20:assert(abs(row.saved-2)<1e-8)
 var hole=terrain.duplicate(true)
 var values=heights.duplicate()
 for x in range(201):values[100*201+x]=NAN
 hole.Heights=values
 state.source=hole
 result=Comparison.calculate(state,1,40)
 var found_missing=false
 for row in result.rows:
  if row.d==0:
   assert(row.status=="nodata" and row.ground==null and row.current==null and row.saved==null and row.delta==null)
   found_missing=true
 assert(found_missing and result.missing>0)
 state.source=terrain
 state.saved=current
 result=Comparison.calculate(state,1,30)
 for row in result.rows:assert(row.delta==0)
 for station in [-1,101,NAN,INF]:
  state.station=station
  assert(not Comparison.calculate(state,1,30).ok)
 state.station=50
 assert(not Comparison.calculate(state,0.1,10000).ok)
 assert(not Comparison.calculate(state,0,30).ok and not Comparison.calculate(state,1,4).ok)
 var empty=current.duplicate(true)
 empty.pi_route=PackedVector3Array()
 state.current=empty
 assert(not Comparison.calculate(state,1,30).ok)
 print("PASS SECTION TABLE CORE: world coordinates, centre/edge events, crossfall/offset sign, native surface match, shifted road, null vs zero and invalid/budget/empty-route rejection")
 quit(0)
