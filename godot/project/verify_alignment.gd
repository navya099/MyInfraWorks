extends SceneTree
var failures=[]
func check(condition,label):
 print(("PASS " if condition else "FAIL ")+label)
 if not condition:
  failures.append(label)
func zeros():
 return PackedFloat64Array([0,0,0])
func _initialize():
 var engine=ClassDB.instantiate("KRoadAlignment")
 var p=PackedVector3Array([Vector3(0,100,0),Vector3(1000,120,0),Vector3(1000,100,1000)])
 var r=PackedFloat64Array([0,200,0])
 var result=engine.configure(p,r,zeros(),zeros())
 check(result.ok,"circular fillet accepted")
 check(abs(result.length-(1600+100*PI))<1e-8,"quarter circle analytic length")
 var start=engine.sample(800)
 var mid=engine.sample(800+50*PI)
 var end=engine.sample(800+100*PI)
 check(abs(start.x-800)<1e-8 and abs(start.y)<1e-8,"circular TS position")
 check(abs(mid.x-(800+200/sqrt(2)))<1e-8 and abs(mid.y-(200-200/sqrt(2)))<1e-8,"circular midpoint analytic position")
 check(abs(end.x-1000)<1e-8 and abs(end.y-200)<1e-8 and abs(end.heading-PI/2)<1e-8,"circular end position and direction")
 var ls=PackedFloat64Array([0,80,0])
 result=engine.configure(p,r,ls,zeros())
 check(result.ok,"S-C-S clothoid accepted")
 var elements=result.elements
 check(elements.size()==5 and elements[1].type=="spiral_in" and elements[2].type=="arc" and elements[3].type=="spiral_out","line-spiral-arc-spiral-line sequence")
 var continuous=true
 for i in range(1,elements.size()):
  var s=elements[i].station
  var before=engine.sample(s-0.00001)
  var after=engine.sample(s+0.00001)
  continuous=continuous and abs(before.x-after.x)<0.0001 and abs(before.y-after.y)<0.0001 and abs(before.heading-after.heading)<0.00001 and abs(before.curvature-after.curvature)<0.00001
 check(continuous,"position, tangent, curvature continuous at clothoid joins")
 var spiral=elements[1]
 for f in [0.0,0.25,0.5,0.75,1.0]:
  check(abs(engine.sample(spiral.station+f*80).curvature-f/200)<1e-8,"clothoid curvature linear %.2f" % f)
 # Independent high-resolution midpoint integration of the entry spiral.
 var ix=0.0
 var iy=0.0
 var count=20000
 for i in range(count):
  var s=80.0*(i+0.5)/count
  var theta=s*s/(2*200*80)
  ix+=cos(theta)*80/count
  iy+=sin(theta)*80/count
 var entry=engine.sample(spiral.station)
 var sc=engine.sample(spiral.station+80)
 check(abs(sc.x-entry.x-ix)<0.000001 and abs(sc.y-entry.y-iy)<0.000001,"clothoid coordinates match independent quadrature")
 var right=engine.sample(result.length/2)
 var mirrored=PackedVector3Array([Vector3(0,100,0),Vector3(1000,120,0),Vector3(1000,100,-1000)])
 var left=ClassDB.instantiate("KRoadAlignment")
 var mirror=left.configure(mirrored,r,ls,zeros())
 var sample_left=left.sample(mirror.length/2)
 check(abs(right.x-sample_left.x)<1e-8 and abs(right.y+sample_left.y)<1e-8 and abs(right.curvature+sample_left.curvature)<1e-8,"left/right curves mirror exactly")
 var old_length=result.length
 var invalid=engine.configure(p,PackedFloat64Array([0,2000,0]),ls,zeros())
 check(not invalid.ok and abs(engine.geometry().length-old_length)<1e-8,"oversized radius rejected without mutating alignment")
 check(not engine.configure(p,r,PackedFloat64Array([0,500,0]),zeros()).ok,"excessive spiral length rejected")
 var vp=PackedVector3Array([Vector3(0,100,0),Vector3(1000,120,0),Vector3(2000,100,0)])
 var vertical=PackedFloat64Array([0,200,0])
 result=engine.configure(vp,zeros(),zeros(),vertical)
 check(result.ok,"parabolic vertical curve accepted")
 check(abs(engine.sample(900).elevation-118)<1e-8 and abs(engine.sample(900).grade-.02)<1e-8,"vertical curve start elevation and grade")
 check(abs(engine.sample(1000).elevation-119)<1e-8 and abs(engine.sample(1000).grade)<1e-8,"crest curve midpoint follows parabola, not PVI")
 check(abs(engine.sample(1100).elevation-118)<1e-8 and abs(engine.sample(1100).grade+.02)<1e-8,"vertical curve end elevation and grade")
 var sag=PackedVector3Array([Vector3(0,120,0),Vector3(1000,100,0),Vector3(2000,120,0)])
 check(engine.configure(sag,zeros(),zeros(),vertical).ok and abs(engine.sample(1000).elevation-101)<1e-8,"sag curve parabola")
 var four=PackedVector3Array([Vector3(0,100,0),Vector3(1000,120,0),Vector3(2000,100,0),Vector3(3000,120,0)])
 check(not engine.configure(four,PackedFloat64Array([0,0,0,0]),PackedFloat64Array([0,0,0,0]),PackedFloat64Array([0,1400,1400,0])).ok,"overlapping vertical curves rejected")
 result=engine.configure(p,r,ls,vertical)
 var sampled=engine.polyline()
 check(result.ok and sampled.size()>20,"combined alignment tessellated for corridor")
 var last=engine.sample(result.length)
 check(abs(last.x-1000)<1e-8 and abs(last.y-1000)<1e-8 and abs(last.elevation-100)<1e-8,"combined alignment reaches endpoint")
 var reverse=PackedVector3Array([Vector3(0,100,0),Vector3(1000,120,0),Vector3(1000,100,500),Vector3(2000,110,500)])
 check(not engine.configure(reverse,PackedFloat64Array([0,300,300,0]),PackedFloat64Array([0,0,0,0]),PackedFloat64Array([0,0,0,0])).ok,"adjacent horizontal curve overlap rejected")
 var triangular=engine.configure(p,r,PackedFloat64Array([0,200*PI/2,0]),zeros())
 check(triangular.ok and triangular.elements.size()==4,"zero circular length joins two clothoids")
 check(not engine.configure(vp,zeros(),zeros(),PackedFloat64Array([0,3000,0])).ok,"vertical curve outside route rejected")
 check(not engine.configure(p,PackedFloat64Array([0,1e300,0]),zeros(),zeros()).ok,"overflow-scale radius rejected")
 check(not engine.configure(p,r,PackedFloat64Array([0,NAN,0]),zeros()).ok,"non-finite curve parameter rejected")
 print("PASS ALIGNMENT CORE" if failures.is_empty() else "FAIL ALIGNMENT CORE")
 quit(0 if failures.is_empty() else 1)
