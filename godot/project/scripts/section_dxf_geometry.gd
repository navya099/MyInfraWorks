extends RefCounted
const Reference=preload("res://scripts/plan_reference.gd")
const Surface=preload("res://scripts/section_reference.gd")
const MAX_SECTIONS=500
const MAX_SAMPLES=100000

static func fail(message):
 return {"ok":false,"error":message}

static func pair(lines,code,value):
 lines.append(str(code))
 lines.append(str(value))

static func polyline(lines,layer,points):
 if points.is_empty():return
 if points.size()==1:
  pair(lines,0,"POINT");pair(lines,8,layer)
  pair(lines,10,"%.9f" % points[0][0]);pair(lines,20,"%.9f" % points[0][1]);pair(lines,30,0)
  return
 pair(lines,0,"POLYLINE");pair(lines,8,layer);pair(lines,66,1)
 pair(lines,10,0);pair(lines,20,0);pair(lines,30,0);pair(lines,70,8)
 for point in points:
  pair(lines,0,"VERTEX");pair(lines,8,layer)
  pair(lines,10,"%.9f" % point[0]);pair(lines,20,"%.9f" % point[1]);pair(lines,30,0);pair(lines,70,32)
 pair(lines,0,"SEQEND");pair(lines,8,layer)

static func text(lines,x,y,height,value,layer="KROAD_SEC_TEXT"):
 pair(lines,0,"TEXT");pair(lines,8,layer)
 pair(lines,10,"%.9f" % x);pair(lines,20,"%.9f" % y);pair(lines,30,0)
 pair(lines,40,"%.9f" % height);pair(lines,1,value);pair(lines,50,0)

static func trace(lines,layer,values,component,ox,oy,datum):
 var points=[]
 var runs=0
 for i in range(0,values.size(),3):
  var elevation=values[i+component]
  if is_finite(elevation):points.append([ox+values[i],oy+elevation-datum])
  else:
   if not points.is_empty():polyline(lines,layer,points);runs+=1;points=[]
 if not points.is_empty():polyline(lines,layer,points);runs+=1
 return runs

static func calculate_job(snapshot,station_step,half,lateral_step,columns):
 var started=Time.get_ticks_usec()
 if typeof(columns)!=TYPE_INT:return fail("배치 열 수는 정수여야 합니다.")
 if not is_finite(station_step) or station_step<1 or station_step>10000 or not is_finite(half) or half<5 or half>10000 or not is_finite(lateral_step) or lateral_step<0.1 or lateral_step>50 or columns<1 or columns>8:return fail("측점 간격 1~10000m / 반폭 5~10000m / 횡단 간격 0.1~50m / 배치 1~8열 범위입니다.")
 if snapshot.pi_route.size()<2:return fail("두 점 이상의 현재 노선이 필요합니다.")
 var reference=Reference.build(snapshot)
 if not reference.ok:return reference
 var count=ceili(reference.length/station_step)
 if count+1>MAX_SECTIONS:return fail("횡단 수가 500개를 넘습니다. 측점 간격을 늘리세요.")
 var stations=[0.0]
 for i in range(1,count):
  if reference.length-i*station_step>=0.0000001:stations.append(i*station_step)
 stations.append(reference.length)
 var lateral_count=ceili(2.0*half/lateral_step)
 if lateral_count+1>20000:return fail("한 횡단의 표본이 20000개를 넘습니다.")
 var offsets=[-half,0.0,half]
 for i in range(1,lateral_count):offsets.append(-half+i*lateral_step)
 for edge in [-snapshot.width/2.0,snapshot.width/2.0]:
  if edge>=-half and edge<=half:offsets.append(edge)
 offsets.sort()
 var unique=PackedFloat64Array()
 for d in offsets:
  if unique.is_empty() or abs(d-unique[-1])>=0.0000001:unique.append(d)
 unique[-1]=half
 if stations.size()*unique.size()>MAX_SAMPLES:return fail("전체 표본이 100000개를 넘습니다. 측점/횡단 간격을 늘리거나 반폭을 줄이세요.")
 var surface=Surface.build(reference,snapshot,snapshot.terrain,snapshot.source)
 if not surface.ok:return surface
 var sections=[]
 var max_height=10.0
 var missing_total=0
 for station in stations:
  var at=reference.alignment.sample(station)
  var values=PackedFloat64Array()
  var low=INF
  var high=-INF
  var ground_missing=0
  var design_missing=0
  for d in unique:
   var x=at.point.x+at.normal.x*d
   var y=at.point.z+at.normal.y*d
   var ground=surface.core.sample_height(snapshot.source,x,y)
   var planned=Surface.height(surface,x,y)
   values.append_array(PackedFloat64Array([d,ground,planned]))
   if not is_finite(ground):ground_missing+=1
   if not is_finite(planned):design_missing+=1
   for value in [ground,planned]:
    if is_finite(value):low=min(low,value);high=max(high,value)
  var datum=floor(low/10.0)*10.0 if is_finite(low) else floor((at.elevation+snapshot.offset)/10.0)*10.0
  if is_finite(high):max_height=max(max_height,high-datum)
  sections.append({"station":station,"datum":datum,"centre":at.elevation+snapshot.offset,"values":values,"ground_missing":ground_missing,"design_missing":design_missing})
  missing_total+=ground_missing
 var text_height=clamp(half/40.0,0.25,2.0)
 var margin=max(10.0,text_height*10)
 var cell_width=2.0*half+2.0*margin
 var cell_height=max_height+2.0*margin+text_height*8
 var lines=PackedStringArray()
 pair(lines,999,"MYINFRAWORKS; UNITS=METERS; SECTION_LAYOUT; H_V=1; ALL_ENTITY_Z=0; NO_EPSG_COORDINATES")
 pair(lines,999,"SAMPLING STA_STEP=%.9f HALF=%.9f LATERAL_STEP=%.9f" % [station_step,half,lateral_step])
 pair(lines,999,"DESIGN WIDTH=%.9f OFFSET=%.9f LEFT=%.9f RIGHT=%.9f FILL=%.9f CUT=%.9f" % [snapshot.width,snapshot.offset,snapshot.left_fall,snapshot.right_fall,snapshot.slope,snapshot.cut_slope])
 pair(lines,0,"SECTION");pair(lines,2,"HEADER")
 pair(lines,9,"$ACADVER");pair(lines,1,"AC1009")
 pair(lines,9,"$LUNITS");pair(lines,70,2);pair(lines,9,"$LUPREC");pair(lines,70,6)
 pair(lines,9,"$INSBASE");pair(lines,10,0);pair(lines,20,0);pair(lines,30,0)
 pair(lines,9,"$EXTMIN");pair(lines,10,0);pair(lines,20,-((sections.size()-1)/columns)*cell_height);pair(lines,30,0)
 pair(lines,9,"$EXTMAX");pair(lines,10,min(columns,sections.size())*cell_width);pair(lines,20,cell_height);pair(lines,30,0)
 pair(lines,0,"ENDSEC")
 pair(lines,0,"SECTION");pair(lines,2,"TABLES")
 pair(lines,0,"TABLE");pair(lines,2,"LTYPE");pair(lines,70,1)
 pair(lines,0,"LTYPE");pair(lines,2,"CONTINUOUS");pair(lines,70,0);pair(lines,3,"Solid line");pair(lines,72,65);pair(lines,73,0);pair(lines,40,0);pair(lines,0,"ENDTAB")
 pair(lines,0,"TABLE");pair(lines,2,"LAYER");pair(lines,70,5)
 for layer in [{"name":"0","color":7},{"name":"KROAD_SEC_GROUND","color":3},{"name":"KROAD_SEC_DESIGN","color":2},{"name":"KROAD_SEC_AXIS","color":8},{"name":"KROAD_SEC_TEXT","color":7}]:
  pair(lines,0,"LAYER");pair(lines,2,layer.name);pair(lines,70,0);pair(lines,62,layer.color);pair(lines,6,"CONTINUOUS")
 pair(lines,0,"ENDTAB");pair(lines,0,"ENDSEC")
 pair(lines,0,"SECTION");pair(lines,2,"BLOCKS");pair(lines,0,"ENDSEC")
 pair(lines,0,"SECTION");pair(lines,2,"ENTITIES")
 var summaries=[]
 for i in range(sections.size()):
  var section=sections[i]
  var ox=(i%columns)*cell_width+margin+half
  var oy=-(i/columns)*cell_height+margin
  pair(lines,999,"SECTION_META "+JSON.stringify({"index":i+1,"station":section.station,"datum":section.datum,"origin_x":ox,"origin_y":oy,"half":half}))
  polyline(lines,"KROAD_SEC_AXIS",[[ox-half,oy],[ox+half,oy]])
  polyline(lines,"KROAD_SEC_AXIS",[[ox,oy],[ox,oy+max_height]])
  var ground_runs=trace(lines,"KROAD_SEC_GROUND",section.values,1,ox,oy,section.datum)
  var design_runs=trace(lines,"KROAD_SEC_DESIGN",section.values,2,ox,oy,section.datum)
  text(lines,ox-half,oy+max_height+text_height*6.5,text_height,"STA %.3f | H:V 1:1" % section.station)
  text(lines,ox-half,oy+max_height+text_height*5,text_height,"DATUM %.3f | CENTER %.3f" % [section.datum,section.centre])
  text(lines,ox-half,oy+max_height+text_height*3.5,text_height,"GROUND MISSING %d | DESIGN MISSING %d / %d" % [section.ground_missing,section.design_missing,unique.size()])
  text(lines,ox-half,oy+max_height+text_height*2,text_height,"HALF %.2f | LATERAL %.2f" % [half,lateral_step])
  for d in [-half,0.0,half]:text(lines,ox+d,oy-text_height*2,text_height,"%.3f" % d)
  summaries.append({"station":section.station,"datum":section.datum,"ground_missing":section.ground_missing,"design_missing":section.design_missing,"ground_runs":ground_runs,"design_runs":design_runs})
 pair(lines,0,"ENDSEC");pair(lines,0,"EOF")
 return {"ok":true,"text":"\n".join(lines)+"\n","sections":summaries,"samples":stations.size()*unique.size(),"lateral_count":unique.size(),"missing":missing_total,"length":reference.length,"station_step":station_step,"half":half,"lateral_step":lateral_step,"columns":columns,"ms":(Time.get_ticks_usec()-started)/1000.0}
