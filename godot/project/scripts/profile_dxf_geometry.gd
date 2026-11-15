extends RefCounted
const Reference=preload("res://scripts/plan_reference.gd")
const Writer=preload("res://scripts/section_dxf_geometry.gd")

static func fail(message):
 return {"ok":false,"error":message}

static func calculate_job(snapshot,step,begin,finish,factor):
 var started=Time.get_ticks_usec()
 if not is_finite(step) or step<1 or step>10000 or not is_finite(begin) or not is_finite(finish) or begin<0 or finish-begin<1 or not is_finite(factor) or factor<1 or factor>100:return fail("간격 1~10000m / 길이 1m 이상인 STA 범위 / 세로 확대 1~100배가 필요합니다.")
 if snapshot.pi_route.size()<2 or not is_finite(snapshot.offset):return fail("유효한 현재 노선과 보정고가 필요합니다.")
 step=float(step)
 begin=float(begin)
 finish=float(finish)
 factor=float(factor)
 var reference=Reference.build(snapshot)
 if not reference.ok:return reference
 if finish>reference.length:return fail("끝 STA가 현재 노선 범위를 벗어났습니다.")
 var count=ceili((finish-begin)/step)
 if count+1>20000:return fail("표본이 20000개를 넘습니다. 범위를 줄이거나 간격을 늘리세요.")
 var events=[{"s":begin,"priority":4},{"s":finish,"priority":4}]
 for i in range(1,count):events.append({"s":begin+i*step,"priority":1})
 var info=reference.info
 for i in range(info.pvi_stations.size()):
  var s=info.pvi_stations[i]
  events.append({"s":s,"priority":2})
  var length=info.pvi_lengths[i]
  if length>0:
   events.append({"s":s-length/2.0,"priority":2})
   events.append({"s":s+length/2.0,"priority":2})
   var g1=(info.pvi_heights[i]-info.pvi_heights[i-1])/(s-info.pvi_stations[i-1])
   var g2=(info.pvi_heights[i+1]-info.pvi_heights[i])/(info.pvi_stations[i+1]-s)
   if abs(g2-g1)>1e-12:
    var x=-g1*length/(g2-g1)
    if x>0 and x<length:events.append({"s":s-length/2.0+x,"priority":2})
 for element in info.elements:
  events.append({"s":element.station,"priority":2})
  events.append({"s":element.station+element.length,"priority":2})
 events.sort_custom(func(a,b):return a.s<b.s)
 var unique=[]
 for event in events:
  if event.s<begin or event.s>finish:continue
  if not unique.is_empty() and abs(unique[-1].s-event.s)<0.000001:
   if event.priority>unique[-1].priority:unique[-1]=event
  else:unique.append(event)
 if unique.size()>20000:return fail("경계 포함 표본이 20000개를 넘습니다.")
 var core=ClassDB.instantiate("KRoadCore")
 var rows=PackedFloat64Array()
 var stations=PackedFloat64Array()
 var low=INF
 var high=-INF
 var missing=0
 for event in unique:
  var at=reference.alignment.sample(event.s)
  var planned=at.elevation+snapshot.offset
  if not is_finite(planned):return fail("계획고가 유효하지 않습니다.")
  var ground=core.sample_height(snapshot.source,at.x,at.y)
  if not is_finite(ground):missing+=1
  for value in [planned,ground]:
   if is_finite(value):low=min(low,value);high=max(high,value)
  rows.append_array(PackedFloat64Array([event.s-begin,ground,planned]))
  stations.append(event.s)
 var datum=floor(low/10.0)*10.0
 for i in range(0,rows.size(),3):
  rows[i+1]=(rows[i+1]-datum)*factor
  rows[i+2]=(rows[i+2]-datum)*factor
 var span=finish-begin
 var text_height=clamp(span/100.0,0.01,100.0)
 var plot_height=max(10.0*factor,(high-datum)*factor)
 var lines=PackedStringArray()
 Writer.pair(lines,999,"MYINFRAWORKS; PROFILE_LAYOUT; UNITS=METERS; ALL_ENTITY_Z=0; NO_EPSG_COORDINATES")
 Writer.pair(lines,999,"PROFILE_META "+JSON.stringify({"start":begin,"end":finish,"datum":datum,"vertical_factor":factor,"step":step,"offset":snapshot.offset}))
 Writer.pair(lines,0,"SECTION");Writer.pair(lines,2,"HEADER")
 Writer.pair(lines,9,"$ACADVER");Writer.pair(lines,1,"AC1009")
 Writer.pair(lines,9,"$LUNITS");Writer.pair(lines,70,2);Writer.pair(lines,9,"$LUPREC");Writer.pair(lines,70,6)
 Writer.pair(lines,9,"$INSBASE");Writer.pair(lines,10,0);Writer.pair(lines,20,0);Writer.pair(lines,30,0)
 Writer.pair(lines,9,"$EXTMIN");Writer.pair(lines,10,-text_height*14);Writer.pair(lines,20,-text_height*5);Writer.pair(lines,30,0)
 Writer.pair(lines,9,"$EXTMAX");Writer.pair(lines,10,span+text_height*12);Writer.pair(lines,20,plot_height+text_height*10);Writer.pair(lines,30,0)
 Writer.pair(lines,0,"ENDSEC")
 Writer.pair(lines,0,"SECTION");Writer.pair(lines,2,"TABLES")
 Writer.pair(lines,0,"TABLE");Writer.pair(lines,2,"LTYPE");Writer.pair(lines,70,1)
 Writer.pair(lines,0,"LTYPE");Writer.pair(lines,2,"CONTINUOUS");Writer.pair(lines,70,0);Writer.pair(lines,3,"Solid line");Writer.pair(lines,72,65);Writer.pair(lines,73,0);Writer.pair(lines,40,0);Writer.pair(lines,0,"ENDTAB")
 Writer.pair(lines,0,"TABLE");Writer.pair(lines,2,"LAYER");Writer.pair(lines,70,5)
 for layer in [{"name":"0","color":7},{"name":"KROAD_PROF_GROUND","color":3},{"name":"KROAD_PROF_DESIGN","color":2},{"name":"KROAD_PROF_AXIS","color":8},{"name":"KROAD_PROF_TEXT","color":7}]:
  Writer.pair(lines,0,"LAYER");Writer.pair(lines,2,layer.name);Writer.pair(lines,70,0);Writer.pair(lines,62,layer.color);Writer.pair(lines,6,"CONTINUOUS")
 Writer.pair(lines,0,"ENDTAB");Writer.pair(lines,0,"ENDSEC")
 Writer.pair(lines,0,"SECTION");Writer.pair(lines,2,"BLOCKS");Writer.pair(lines,0,"ENDSEC")
 Writer.pair(lines,0,"SECTION");Writer.pair(lines,2,"ENTITIES")
 Writer.polyline(lines,"KROAD_PROF_AXIS",[[0,0],[span,0]])
 Writer.polyline(lines,"KROAD_PROF_AXIS",[[0,0],[0,plot_height]])
 for i in range(5):
  var x=span*i/4.0
  var y=plot_height*i/4.0
  Writer.text(lines,x,-text_height*2,text_height,"%.3f" % (begin+x),"KROAD_PROF_TEXT")
  Writer.text(lines,-text_height*12,y,text_height,"%.3f" % (datum+y/factor),"KROAD_PROF_TEXT")
 var ground_runs=Writer.trace(lines,"KROAD_PROF_GROUND",rows,1,0,0,0)
 Writer.trace(lines,"KROAD_PROF_DESIGN",rows,2,0,0,0)
 Writer.text(lines,0,plot_height+text_height*7,text_height,"STA %.3f TO %.3f | VERTICAL FACTOR %.3f" % [begin,finish,factor],"KROAD_PROF_TEXT")
 Writer.text(lines,0,plot_height+text_height*5.5,text_height,"DATUM %.3f | OFFSET %.3f | STEP %.3f" % [datum,snapshot.offset,step],"KROAD_PROF_TEXT")
 Writer.text(lines,0,plot_height+text_height*4,text_height,"GROUND MISSING %d / %d | X=STA-START | Y=(ELEV-DATUM)*FACTOR" % [missing,unique.size()],"KROAD_PROF_TEXT")
 Writer.pair(lines,0,"ENDSEC");Writer.pair(lines,0,"EOF")
 return {"ok":true,"text":"\n".join(lines)+"\n","begin":begin,"end":finish,"datum":datum,"factor":factor,"step":step,"stations":stations,"missing":missing,"ground_runs":ground_runs,"low":low,"high":high,"ms":(Time.get_ticks_usec()-started)/1000.0}
