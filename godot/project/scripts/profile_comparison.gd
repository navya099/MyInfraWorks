extends RefCounted

static func fail(message):
 return {"ok":false,"error":message}

static func calculate(current,saved,name,step):
 var started=Time.get_ticks_usec()
 if not is_finite(step) or step<0.1 or step>10000:return fail("측점 간격은 0.1~10,000m입니다.")
 var alignments=[]
 var infos=[]
 for design in [current,saved]:
  var alignment=ClassDB.instantiate("KRoadAlignment")
  var info=alignment.configure_independent(design.pi_route,design.radii,design.spirals,design.pvi_stations,design.pvi_heights,design.pvi_lengths)
  if not info.ok:return fail(str(info.get("error","선형 오류")))
  if info.length<=0:return fail("두 노선 모두 유효한 선형이 필요합니다.")
  if not is_finite(design.offset):return fail("계획고 보정이 유효하지 않습니다.")
  alignments.append(alignment)
  infos.append(info)
 var common=min(infos[0].length,infos[1].length)
 var count=ceili(common/step)
 if count+1>20000:return fail("측점 수가 20,000개를 넘습니다. 간격을 늘리세요.")
 var events=[{"s":0.0,"tag":"start","priority":3},{"s":common,"tag":"common_end","priority":4}]
 for i in range(1,count):events.append({"s":i*step,"tag":"regular","priority":1})
 for side in range(2):
  var info=infos[side]
  var prefix="current_" if side==0 else "saved_"
  for element in info.elements:
   for station in [element.station,element.station+element.length]:events.append({"s":station,"tag":prefix+"geometry_boundary","priority":2})
  for station in info.pi_stations:events.append({"s":station,"tag":prefix+"PI","priority":2})
  for i in range(info.pvi_stations.size()):
   events.append({"s":info.pvi_stations[i],"tag":prefix+"PVI","priority":2})
   if info.pvi_lengths[i]>0:
    events.append({"s":info.pvi_stations[i]-info.pvi_lengths[i]/2.0,"tag":prefix+"BVC","priority":2})
    events.append({"s":info.pvi_stations[i]+info.pvi_lengths[i]/2.0,"tag":prefix+"EVC","priority":2})
 events.sort_custom(func(a,b):return a.s<b.s)
 var unique=[]
 for event in events:
  if event.s<0 or event.s>common:continue
  var distinct_end=event.tag=="common_end" and not unique.is_empty() and unique[-1].s==0 and event.s>0
  if not unique.is_empty() and abs(unique[-1].s-event.s)<0.000001 and not distinct_end:
   if event.tag not in unique[-1].tags:unique[-1].tags.append(event.tag)
   if event.priority>unique[-1].priority:
    unique[-1].s=event.s
    unique[-1].priority=event.priority
  else:unique.append({"s":event.s,"tags":[event.tag],"priority":event.priority})
 if unique.size()>20000:return fail("경계 포함 측점 수가 20,000개를 넘습니다. 간격을 늘리세요.")
 var rows=[]
 for event in unique:
  var a=alignments[0].sample(event.s)
  var b=alignments[1].sample(event.s)
  var current_height=a.elevation+current.offset
  var saved_height=b.elevation+saved.offset
  rows.append({"station":event.s,"current_height":current_height,"saved_height":saved_height,"delta":current_height-saved_height,"current_x":a.x,"current_y":a.y,"saved_x":b.x,"saved_y":b.y,"separation":sqrt(pow(a.x-b.x,2)+pow(a.y-b.y,2)),"current_grade":a.grade*100.0,"saved_grade":b.grade*100.0,"events":"|".join(event.tags)})
 return {"ok":true,"rows":rows,"name":name,"step":step,"current_length":infos[0].length,"saved_length":infos[1].length,"common_length":common,"current_offset":current.offset,"saved_offset":saved.offset,"ms":(Time.get_ticks_usec()-started)/1000.0}
