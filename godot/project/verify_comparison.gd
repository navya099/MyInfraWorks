extends SceneTree
const Model=preload("res://scripts/road_model.gd")
const Comparison=preload("res://scripts/alternative_comparison.gd")
const Token=preload("res://scripts/comparison_token.gd")
var failures=0
func check(value,label):
 if value:print("PASS "+label)
 else:
  failures+=1
  push_error("FAIL "+label)
func _initialize():
 var h=PackedFloat64Array()
 h.resize(201*201)
 h.fill(0)
 var terrain={"Nx":201,"Ny":201,"Dx":1.0,"Dy":1.0,"Min":0.0,"Max":0.0,"Heights":h}
 var model=Model.new()
 model.terrain=terrain
 model.source=terrain
 model.route=PackedVector3Array([Vector3(50,2,100),Vector3(150,2,100)])
 assert(model.rebuild_alignment()=="")
 var entries=[{"name":"A","design":model.edit_state()}]
 model.offset=1
 assert(model.rebuild_alignment()=="")
 entries.append({"name":"B","design":model.edit_state()})
 var state={"entries":entries,"terrain":terrain,"source":terrain}
 var result=Comparison.calculate_comparison(state,25,30,1)
 check(result.ok and result.rows.size()==2,"all alternatives calculated under one set of conditions")
 check(result.rows[0].status=="complete" and abs(result.rows[0].fill-4600)<1e-6,"first analytic fill volume")
 check(result.rows[1].status=="complete" and abs(result.rows[1].fill-7350)<1e-6 and abs(result.rows[1].fill_delta-2750)<1e-6,"second analytic volume and complete-only baseline difference")
 var hole=terrain.duplicate(true)
 var values=h.duplicate()
 for y in range(201):values[y*201+100]=NAN
 hole.Heights=values
 state.source=hole
 result=Comparison.calculate_comparison(state,25,30,1)
 check(result.rows[0].status=="partial" and abs(result.rows[0].coverage-0.5)<1e-8 and result.rows[0].fill_delta==null and result.rows[1].fill_delta==null,"partial coverage has no misleading baseline deltas")
 values.fill(NAN)
 hole.Heights=values
 state.source=hole
 result=Comparison.calculate_comparison(state,25,30,1)
 check(result.rows[0].status=="missing" and result.rows[0].cut==null and result.rows[0].fill==null,"no valid intervals are missing quantities rather than zero")
 state.source=terrain
 var flat=entries[0].design.duplicate(true)
 flat.pvi_heights=PackedFloat64Array([0,0])
 state.entries=[{"name":"Zero","design":flat}]
 result=Comparison.calculate_comparison(state,25,30,1)
 check(result.rows[0].status=="complete" and result.rows[0].cut==0 and result.rows[0].fill==0,"valid zero quantities remain numeric")
 var bad=flat.duplicate(true)
 bad.cut_slope=0
 state.entries=[{"name":"Bad","design":bad},{"name":"Zero","design":flat}]
 result=Comparison.calculate_comparison(state,25,30,1)
 check(result.rows[0].status=="error" and result.rows[0].cut==null and result.rows[0].coverage==null and result.rows[1].status=="complete" and result.rows[1].cut_delta==null,"per-alternative errors retained without manufacturing deltas")
 var token=Token.new()
 token.cancel()
 check(Comparison.calculate_comparison(state,25,30,1,token).get("cancelled",false),"cooperative cancellation")
 check(not Comparison.calculate_comparison(state,0,30,1).ok,"invalid batch settings rejected")
 state.entries=[]
 check(not Comparison.calculate_comparison(state,25,30,1).ok,"empty library rejected")
 if failures==0:print("PASS ALTERNATIVE COMPARISON CORE")
 quit(0 if failures==0 else 1)
