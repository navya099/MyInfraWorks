extends SceneTree
var failures=[]
func check(value,label):
 print(("PASS " if value else "FAIL ")+label)
 if not value: failures.append(label)
func _initialize():
 var a=ClassDB.instantiate("KRoadAlignment")
 var points=PackedVector3Array([Vector3(0,100,0),Vector3(1000,100,0),Vector3(2000,100,0)])
 var zeros=PackedFloat64Array([0,0,0])
 var stations=PackedFloat64Array([0,600,1400,2000])
 var heights=PackedFloat64Array([100,112,108,116])
 var lengths=PackedFloat64Array([0,200,200,0])
 var result=a.configure_independent(points,zeros,zeros,stations,heights,lengths)
 check(result.ok and result.pvi_stations.size()==4 and result.pi_stations.size()==3,"PVI count independent of PI count")
 check(abs(a.sample(600).elevation-111.375)<1e-9,"independent crest PVI analytic parabola")
 check(abs(a.sample(500).grade-.02)<1e-9 and abs(a.sample(700).grade+.005)<1e-9,"independent curve tangent grades")
 check(abs(a.sample(1400).elevation-(108+(.0133333333333333+.005)*25))<1e-9,"independent sag curve analytic parabola")
 var xy=a.sample(900)
 var changed=heights.duplicate()
 changed[1]=115
 check(a.configure_independent(points,zeros,zeros,stations,changed,lengths).ok,"independent PVI height update accepted")
 check(abs(a.sample(900).x-xy.x)<1e-9 and abs(a.sample(900).y-xy.y)<1e-9,"vertical edit leaves horizontal geometry unchanged")
 var longer=points.duplicate()
 longer[2].x=2200
 result=a.configure_independent(longer,zeros,zeros,stations,heights,lengths)
 check(result.ok and result.pvi_stations[1]==600 and result.pvi_stations[2]==1400 and result.pvi_stations[3]==2200,"horizontal change preserves interior stations and anchors endpoint")
 var short=PackedVector3Array([Vector3(0,100,0),Vector3(500,100,0),Vector3(800,100,0)])
 check(not a.configure_independent(short,zeros,zeros,stations,heights,lengths).ok and a.geometry().length==2200,"route shortening past interior PVI rejected atomically")
 check(not a.configure_independent(points,zeros,zeros,PackedFloat64Array([0,600,600.5,2000]),heights,lengths).ok,"PVI minimum spacing enforced")
 check(not a.configure_independent(points,zeros,zeros,stations,heights,PackedFloat64Array([0,900,900,0])).ok,"independent curve overlap rejected")
 check(not a.configure_independent(points,zeros,zeros,stations,heights,PackedFloat64Array([1,200,200,0])).ok,"endpoint vertical curve rejected")
 # Migrate a legacy S-C-S profile and compare the complete elevation/grade shape.
 var old=ClassDB.instantiate("KRoadAlignment")
 var pi=PackedVector3Array([Vector3(0,100,0),Vector3(1000,130,0),Vector3(1000,110,1000)])
 var r=PackedFloat64Array([0,200,0])
 var ls=PackedFloat64Array([0,80,0])
 var legacy=old.configure(pi,r,ls,PackedFloat64Array([0,300,0]))
 result=a.configure_independent(pi,r,ls,legacy.pvi_stations,legacy.pvi_heights,legacy.pvi_lengths)
 var same=result.ok
 for i in range(201):
  var station=legacy.length*i/200
  var before=old.sample(station)
  var after=a.sample(station)
  same=same and abs(before.elevation-after.elevation)<1e-9 and abs(before.grade-after.grade)<1e-9 and abs(before.x-after.x)<1e-9 and abs(before.y-after.y)<1e-9
 check(same,"legacy linked-to-independent migration preserves shape and grade")
 print("PASS INDEPENDENT PROFILE CORE" if failures.is_empty() else "FAIL INDEPENDENT PROFILE CORE")
 quit(0 if failures.is_empty() else 1)
