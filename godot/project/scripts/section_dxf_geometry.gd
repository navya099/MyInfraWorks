extends RefCounted
const Reference=preload("res://scripts/plan_reference.gd")
const Surface=preload("res://scripts/section_reference.gd")
const MAX_SECTIONS=500
const MAX_SAMPLES=100000

static func station_label(station,decimals=3):
 var scale=int(pow(10,decimals))
 var units=roundi(station*scale)
 var remainder=float(units%(1000*scale))/scale
 var width=3 if decimals==0 else 4+decimals
 return ("%d+%0"+str(width)+"."+str(decimals)+"f") % [units/(1000*scale),remainder]

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

static func parse_extra(text):
 if text.strip_edges().is_empty():return {"ok":true,"stations":[]}
 var parts=text.split(",",true)
 if parts.size()>100:return fail("추가 STA는 최대 100개입니다.")
 var stations=[]
 for part in parts:
  var token=part.strip_edges()
  if not token.is_valid_float() or not is_finite(token.to_float()):return fail("추가 STA는 쉼표로 구분한 유한한 숫자로 입력하세요.")
  stations.append(token.to_float())
 return {"ok":true,"stations":stations}

static func alignment_boundaries(info,begin,finish):
 var candidates=[]
 for element in info.elements:
  candidates.append(float(element.station))
  candidates.append(float(element.station+element.length))
 for station in info.pi_stations:candidates.append(float(station))
 for i in range(info.pvi_stations.size()):
  candidates.append(float(info.pvi_stations[i]))
  if info.pvi_lengths[i]>0:
   candidates.append(float(info.pvi_stations[i]-info.pvi_lengths[i]/2.0))
   candidates.append(float(info.pvi_stations[i]+info.pvi_lengths[i]/2.0))
 return candidates.filter(func(station):return station>=begin and station<=finish)

static func calculate_job(snapshot,station_step,half,lateral_step,columns,station_range={},extra_text="",include_boundaries=false,grid_step=0.0,extras_only=false,chainage_labels=false,label_decimals=3,text_height_override=0.0,number_sections=false,common_datum=null,export_ground=true,export_design=true,export_axes=true):
 var started=Time.get_ticks_usec()
 if not export_ground and not export_design:return fail("원지반·설계선 중 하나 이상 선택하세요.")
 if common_datum!=null and (not (typeof(common_datum) in [TYPE_INT,TYPE_FLOAT]) or not is_finite(common_datum) or abs(common_datum)>100000):return fail("공통 DATUM은 -100000~100000m의 유한한 값이어야 합니다.")
 if not is_finite(text_height_override) or (text_height_override!=0 and (text_height_override<0.1 or text_height_override>5)):return fail("글자 높이는 0(자동) 또는 0.1~5m입니다.")
 if typeof(label_decimals)!=TYPE_INT or label_decimals<0 or label_decimals>3:return fail("STA 소수 자릿수는 0~3 정수입니다.")
 if not is_finite(grid_step) or (grid_step!=0 and (grid_step<0.5 or grid_step>1000)):return fail("격자 간격은 0(끄기) 또는 0.5~1000m입니다.")
 if typeof(columns)!=TYPE_INT:return fail("배치 열 수는 정수여야 합니다.")
 if not is_finite(station_step) or station_step<1 or station_step>10000 or not is_finite(half) or half<5 or half>10000 or not is_finite(lateral_step) or lateral_step<0.1 or lateral_step>50 or columns<1 or columns>8:return fail("측점 간격 1~10000m / 반폭 5~10000m / 횡단 간격 0.1~50m / 배치 1~8열 범위입니다.")
 if snapshot.pi_route.size()<2:return fail("두 점 이상의 현재 노선이 필요합니다.")
 var reference=Reference.build(snapshot)
 if not reference.ok:return reference
 var begin=float(station_range.get("begin",0.0))
 var finish=float(station_range.get("end",reference.length))
 if not is_finite(begin) or not is_finite(finish) or begin<0 or finish>reference.length or finish-begin<1:
  return fail("노선 안에서 길이 1m 이상의 시작·끝 STA를 지정하세요.")
 var parsed=parse_extra(extra_text)
 if not parsed.ok:return parsed
 if extras_only and parsed.stations.is_empty():return fail("추가 STA만 출력하려면 STA를 하나 이상 입력하세요.")
 var stations=[]
 if not extras_only:
  var first=ceili(begin/station_step)
  var last=floori(finish/station_step)
  if last-first+1>MAX_SECTIONS:return fail("횡단 수가 500개를 넘습니다. 간격을 늘리거나 구간을 줄이세요.")
  stations.append(begin)
  for i in range(first,last+1):
   var station=i*station_step
   if station-begin>=0.0000001 and finish-station>=0.0000001:stations.append(station)
  stations.append(finish)
  if stations.size()>MAX_SECTIONS:return fail("구간 양 끝을 포함해 500횡단을 넘습니다. 간격을 늘리거나 구간을 줄이세요.")
 include_boundaries=include_boundaries and not extras_only
 var events=[]
 for station in stations:events.append({"s":station,"priority":4 if station==begin or station==finish else 1,"boundary":false})
 for station in parsed.stations:
  if station<begin or station>finish:return fail("추가 STA는 출력 구간 안에 있어야 합니다.")
  events.append({"s":station,"priority":2,"boundary":false})
 if include_boundaries:
  for station in alignment_boundaries(reference.info,begin,finish):events.append({"s":station,"priority":3,"boundary":true})
 events.sort_custom(func(a,b):return a.s<b.s)
 stations=[]
 var priorities=[]
 var boundary_flags=[]
 for event in events:
  if not stations.is_empty() and abs(stations[-1]-event.s)<0.0000001:
   boundary_flags[-1]=boundary_flags[-1] or event.boundary
   if event.priority>priorities[-1]:stations[-1]=event.s;priorities[-1]=event.priority
  else:
   stations.append(event.s)
   priorities.append(event.priority)
   boundary_flags.append(event.boundary)
 if stations.size()>MAX_SECTIONS:return fail("추가 STA/선형 경계를 포함해 500횡단을 넘습니다. 간격을 늘리거나 추가 측점을 줄이세요.")
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
  if common_datum!=null:
   if is_finite(low) and common_datum>low:return fail("공통 DATUM은 모든 유효 원지반·설계 표고 이하로 지정하세요.")
   datum=float(common_datum)
  if is_finite(high):max_height=max(max_height,high-datum)
  sections.append({"station":station,"datum":datum,"centre":at.elevation+snapshot.offset,"values":values,"ground_missing":ground_missing,"design_missing":design_missing})
  missing_total+=ground_missing
 var text_height=clamp(half/40.0,0.25,2.0) if text_height_override==0 else text_height_override
 var margin=max(10.0,text_height*10)
 var cell_width=2.0*half+2.0*margin
 var cell_height=max_height+2.0*margin+text_height*8
 var grid_offsets=[]
 var grid_levels=[]
 if grid_step>0:
  var grid_first=ceili(-half/grid_step)
  var grid_last=floori(half/grid_step)
  var levels=floori(max_height/grid_step)
  if grid_last-grid_first+1+levels>500 or (grid_last-grid_first+1+levels)*sections.size()>20000:return fail("격자가 너무 많습니다. 격자 간격을 늘리거나 출력 구간/반폭을 줄이세요.")
  for k in range(grid_first,grid_last+1):
   var d=k*grid_step
   if abs(d)>0.0000001 and abs(d)<half-0.0000001:grid_offsets.append(d)
  for k in range(1,levels+1):grid_levels.append(k*grid_step)
 var lines=PackedStringArray()
 if extras_only:pair(lines,999,"SECTION_STATION_MODE=EXPLICIT_ONLY")
 if grid_step>0:pair(lines,999,"SECTION_GRID_STEP=%.9f; H_V=1; ELEVATION_LABELS=DATUM_PLUS_LOCAL_Y" % grid_step)
 if include_boundaries:pair(lines,999,"AUTO_ALIGNMENT_BOUNDARIES=1; PI_PVI_PLAN_ELEMENTS_BVC_EVC; ENDPOINT_PRIORITY")
 for station in parsed.stations:pair(lines,999,"EXTRA_STA=%.9f; MERGE_TOLERANCE=0.0000001m" % station)
 if not station_range.is_empty():pair(lines,999,"STA_RANGE=%.9f,%.9f; ORIGINAL_STATIONING; H_V=1" % [begin,finish])
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
 pair(lines,0,"TABLE");pair(lines,2,"LAYER");pair(lines,70,7 if grid_step>0 else 5)
 for layer in [{"name":"0","color":7},{"name":"KROAD_SEC_GROUND","color":3},{"name":"KROAD_SEC_DESIGN","color":2},{"name":"KROAD_SEC_AXIS","color":8},{"name":"KROAD_SEC_TEXT","color":7}]:
  pair(lines,0,"LAYER");pair(lines,2,layer.name);pair(lines,70,0);pair(lines,62,layer.color);pair(lines,6,"CONTINUOUS")
 if grid_step>0:
  for layer in [{"name":"KROAD_SEC_GRID","color":8},{"name":"KROAD_SEC_GRID_TEXT","color":7}]:
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
  if grid_step>0:
   for d in grid_offsets:polyline(lines,"KROAD_SEC_GRID",[[ox+d,oy],[ox+d,oy+max_height]])
   for level in grid_levels:polyline(lines,"KROAD_SEC_GRID",[[ox-half,oy+level],[ox+half,oy+level]])
   var label_stride=maxi(1,ceili(3.0*text_height/grid_step))
   text(lines,ox-half-margin+text_height,oy,text_height,"%.2f" % section.datum,"KROAD_SEC_GRID_TEXT")
   for k in range(label_stride,grid_levels.size()+1,label_stride):
    var level=k*grid_step
    text(lines,ox-half-margin+text_height,oy+level,text_height,"%.2f" % (section.datum+level),"KROAD_SEC_GRID_TEXT")
  if export_axes:
   polyline(lines,"KROAD_SEC_AXIS",[[ox-half,oy],[ox+half,oy]])
   polyline(lines,"KROAD_SEC_AXIS",[[ox,oy],[ox,oy+max_height]])
  var ground_runs=trace(lines,"KROAD_SEC_GROUND",section.values,1,ox,oy,section.datum) if export_ground else 0
  var design_runs=trace(lines,"KROAD_SEC_DESIGN",section.values,2,ox,oy,section.datum) if export_design else 0
  text(lines,ox-half,oy+max_height+text_height*6.5,text_height,("SEC %03d | " % (i+1) if number_sections else "")+"STA %s | H:V 1:1" % (station_label(section.station,label_decimals) if chainage_labels else ("%."+str(label_decimals)+"f") % section.station))
  text(lines,ox-half,oy+max_height+text_height*5,text_height,"DATUM %.3f | CENTER %.3f" % [section.datum,section.centre])
  text(lines,ox-half,oy+max_height+text_height*3.5,text_height,"GROUND MISSING %d | DESIGN MISSING %d / %d" % [section.ground_missing,section.design_missing,unique.size()])
  text(lines,ox-half,oy+max_height+text_height*2,text_height,"HALF %.2f | LATERAL %.2f" % [half,lateral_step])
  for d in [-half,0.0,half]:text(lines,ox+d,oy-text_height*2,text_height,"%.3f" % d)
  summaries.append({"station":section.station,"datum":section.datum,"ground_missing":section.ground_missing,"design_missing":section.design_missing,"ground_runs":ground_runs,"design_runs":design_runs})
 pair(lines,0,"ENDSEC");pair(lines,0,"EOF")
 return {"ok":true,"text":"\n".join(lines)+"\n","sections":summaries,"samples":stations.size()*unique.size(),"lateral_count":unique.size(),"missing":missing_total,"length":reference.length,"begin":begin,"end":finish,"station_step":station_step,"half":half,"lateral_step":lateral_step,"columns":columns,"extras_only":extras_only,"extra_requested":parsed.stations.size(),"include_boundaries":include_boundaries,"boundary_sections":boundary_flags.count(true),"grid_step":grid_step,"grid_lines":(grid_offsets.size()+grid_levels.size())*sections.size(),"ms":(Time.get_ticks_usec()-started)/1000.0}
