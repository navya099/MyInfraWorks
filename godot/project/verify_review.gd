extends SceneTree
const Review=preload("res://scripts/design_review.gd")
const Model=preload("res://scripts/road_model.gd")

func findings(report,code):
 var rows=[]
 for row in report.issues:
  if row.code==code:rows.append(row)
 return rows

func check(value,label):
 if not value:
  push_error("FAIL "+label)
  quit(1)
  return false
 print("PASS "+label)
 return true

func _initialize():
 var model=Model.new()
 model.demo()
 model.route=PackedVector3Array([Vector3(300,100,3300),Vector3(2700,100,3300),Vector3(2700,100,600)])
 model.radii=PackedFloat64Array([0,300,0])
 model.spirals=PackedFloat64Array([0,50,0])
 assert(model.rebuild_alignment()=="")
 var limits=Review.DEFAULT_LIMITS.duplicate()
 var report=Review.calculate(model.edit_state(),limits)
 if not check(report.ok and report.issues.is_empty(),"equal R/Ls limits accepted, constant grade has no K warning"):return
 limits.min_r=301
 limits.min_ls=51
 report=Review.calculate(model.edit_state(),limits)
 if not check(findings(report,"R_MIN").size()==1 and findings(report,"LS_MIN").size()==1,"horizontal radius and spiral limits"):return
 var radius=findings(report,"R_MIN")[0]
 if not check(radius.index==2 and radius.start<radius.station and radius.station<radius.end,"curve range and PI mapping"):return
 limits.min_r=0
 limits.min_ls=0
 report=Review.calculate(model.edit_state(),limits)
 if not check(report.issues.is_empty(),"zero disables selected comparisons"):return
 model.radii[1]=0
 model.spirals[1]=0
 assert(model.rebuild_alignment()=="")
 report=Review.calculate(model.edit_state(),limits)
 if not check(findings(report,"H_KINK").size()==1,"unsmoothed horizontal corner warning"):return
 model.route[2]=Vector3(4000,100,3300)
 assert(model.rebuild_alignment()=="")
 report=Review.calculate(model.edit_state(),limits)
 if not check(findings(report,"H_KINK").is_empty(),"collinear R=0 point is not a corner"):return
 # Exact analytic crest: +10% to -10%, Lv=200, K=10 m/%.
 model.route=PackedVector3Array([Vector3(0,0,2000),Vector3(2000,0,2000)])
 model.radii=PackedFloat64Array([0,0])
 model.spirals=PackedFloat64Array([0,0])
 model.pvi_stations=PackedFloat64Array([0,1000,2000])
 model.pvi_heights=PackedFloat64Array([0,100,0])
 model.pvi_lengths=PackedFloat64Array([0,200,0])
 assert(model.rebuild_alignment()=="")
 limits.max_grade=5
 limits.min_k_crest=20
 report=Review.calculate(model.edit_state(),limits)
 var crest=findings(report,"K_CREST_MIN")
 if not check(crest.size()==1 and abs(crest[0].value-10)<1e-8 and abs(report.max_grade-10)<1e-8,"crest K uses percentage-point grade difference"):return
 var grade=findings(report,"GRADE_MAX")
 var curve=[]
 for row in grade:
  if row.kind=="PVI":curve.append(row)
 if not check(grade.size()==4 and curve.size()==2 and abs(curve[0].start-900)<1e-8 and abs(curve[0].end-950)<1e-8 and abs(curve[1].start-1050)<1e-8 and abs(curve[1].end-1100)<1e-8,"exact grade threshold crossings on a parabola"):return
 for row in curve:
  if not check(abs(model.sample(row.station).grade*100)>5,"navigation lies inside violating curve interval"):return
 limits.max_grade=10
 limits.min_k_crest=10
 report=Review.calculate(model.edit_state(),limits)
 if not check(report.issues.is_empty(),"grade and K equality accepted"):return
 model.pvi_heights[1]=-100
 assert(model.rebuild_alignment()=="")
 limits.min_k_sag=20
 report=Review.calculate(model.edit_state(),limits)
 if not check(findings(report,"K_SAG_MIN").size()==1 and findings(report,"K_CREST_MIN").is_empty(),"sag and crest limits independent"):return
 model.pvi_lengths[1]=0
 assert(model.rebuild_alignment()=="")
 report=Review.calculate(model.edit_state(),limits)
 if not check(findings(report,"V_KINK").size()==1 and findings(report,"K_SAG_MIN").is_empty(),"Lv=0 grade break warned without fake K"):return
 model.pvi_heights[1]=0
 assert(model.rebuild_alignment()=="")
 report=Review.calculate(model.edit_state(),limits)
 if not check(report.issues.is_empty(),"unchanged grade needs no vertical curve"):return
 limits.max_grade=NAN
 if not check(not Review.calculate(model.edit_state(),limits).ok,"nonfinite limit rejected"):return
 limits.max_grade=-1
 if not check(not Review.calculate(model.edit_state(),limits).ok,"negative limit rejected"):return
 model.route=PackedVector3Array()
 model.pvi_stations=PackedFloat64Array()
 model.pvi_heights=PackedFloat64Array()
 model.pvi_lengths=PackedFloat64Array()
 model.rebuild_alignment()
 if not check(not Review.calculate(model.edit_state(),Review.DEFAULT_LIMITS).ok,"empty alignment rejected"):return
 print("PASS DESIGN REVIEW CORE")
 quit(0)
