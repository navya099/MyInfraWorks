extends SceneTree
const Model=preload("res://scripts/road_model.gd")
const PlanReference=preload("res://scripts/plan_reference.gd")
const SectionReference=preload("res://scripts/section_reference.gd")
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
 var before=model.edit_state()
 var reference=PlanReference.build(before)
 var section=SectionReference.build(reference,before,terrain,terrain)
 assert(section.ok)
 assert(abs(SectionReference.height(section,100,100)-2)<1e-9)
 assert(abs(SectionReference.height(section,100,90)-1.8)<1e-7)
 assert(abs(SectionReference.height(section,100,110)-1.6)<1e-7)
 assert(abs(SectionReference.height(section,100,112)-(1.6-2.0/1.5))<1e-7)
 assert(SectionReference.height(section,100,120)==0 and SectionReference.height(section,190,100)==0)
 for y in range(80,121):assert(abs(SectionReference.height(section,100,y)-model.design(100,y))<1e-9)
 model.offset=5
 assert(model.rebuild_alignment()=="")
 assert(abs(SectionReference.height(section,100,100)-2)<1e-9 and model.design(100,100)>2 and before.offset==0)
 var shifted=before.duplicate(true)
 for i in range(shifted.pi_route.size()):shifted.pi_route[i].z+=20
 var shifted_ref=PlanReference.build(shifted)
 var shifted_section=SectionReference.build(shifted_ref,shifted,terrain,terrain)
 assert(SectionReference.height(shifted_section,100,100)==0 and abs(SectionReference.height(shifted_section,100,120)-2)<1e-9)
 var hole=terrain.duplicate(true)
 var values=heights.duplicate()
 for y in range(201):values[y*201+100]=NAN
 hole.Heights=values
 var missing=SectionReference.build(reference,before,terrain,hole)
 assert(not is_finite(SectionReference.height(missing,100,100)) and not is_finite(SectionReference.height(section,-1,100)))
 var cut=before.duplicate(true)
 cut.pvi_heights=PackedFloat64Array([-2,-2])
 cut.cut_slope=0.5
 var cut_ref=PlanReference.build(cut)
 var cut_section=SectionReference.build(cut_ref,cut,terrain,terrain)
 assert(abs(SectionReference.height(cut_section,100,111)+0.4)<1e-7)
 print("PASS SECTION REFERENCE CORE: same-world road/crossfall/fill/cut, prepared native equivalence, immutable reference, shifted corridor, unaffected terrain and NoData")
 quit(0)
