extends RefCounted
const Reference=preload("res://scripts/plan_reference.gd")
const Surface=preload("res://scripts/section_reference.gd")

static func fail(message):
 return {"ok":false,"error":message}

static func settings(design):
 return [design.width,design.offset,design.left_fall,design.right_fall,design.slope,design.cut_slope]

static func calculate(state,step,half):
 var started=Time.get_ticks_usec()
 if not is_finite(step) or step<0.1 or step>50 or not is_finite(half) or half<5 or half>10000:return fail("횡단 간격은 0.1~50m, 조사 반폭은 5~10,000m입니다.")
 var count=ceili(2.0*half/step)
 if count+1>20000:return fail("표본 수가 20,000개를 넘습니다. 간격을 늘리거나 반폭을 줄이세요.")
 if state.current.pi_route.size()<2 or state.saved.pi_route.size()<2:return fail("현재·보관 노선 모두 두 점 이상의 유효한 노선이 필요합니다.")
 var current=Reference.build(state.current)
 if not current.ok:return current
 var saved=Reference.build(state.saved)
 if not saved.ok:return saved
 if current.length<=0 or saved.length<=0:return fail("현재·보관 노선의 길이가 유효하지 않습니다.")
 var station=state.station
 if not is_finite(station) or station<0 or station>current.length:return fail("현재 노선 범위 안의 유효한 측점이 필요합니다.")
 var a=Surface.build(current,state.current,state.terrain,state.source)
 if not a.ok:return a
 var b=Surface.build(saved,state.saved,state.terrain,state.source)
 if not b.ok:return b
 var at=current.alignment.sample(station)
 # Use the same native point/normal representation as the section canvas.
 var centre_x=at.point.x
 var centre_y=at.point.z
 var nx=at.normal.x
 var ny=at.normal.y
 var events=[{"d":-half,"tag":"left_bound","priority":3},{"d":half,"tag":"right_bound","priority":3},{"d":0.0,"tag":"current_center","priority":3}]
 for i in range(1,count):events.append({"d":-half+i*step,"tag":"regular","priority":1})
 for edge in [-state.current.width/2.0,state.current.width/2.0]:
  if edge>=-half and edge<=half:events.append({"d":edge,"tag":"current_left_edge" if edge<0 else "current_right_edge","priority":2})
 events.sort_custom(func(left,right):return left.d<right.d)
 var unique=[]
 for event in events:
  if not unique.is_empty() and abs(unique[-1].d-event.d)<0.0000001:
   if event.tag not in unique[-1].tags:unique[-1].tags.append(event.tag)
   if event.priority>unique[-1].priority:
    unique[-1].d=event.d
    unique[-1].priority=event.priority
  else:unique.append({"d":event.d,"tags":[event.tag],"priority":event.priority})
 if unique.size()>20000:return fail("경계 포함 표본 수가 20,000개를 넘습니다.")
 var rows=[]
 var missing=0
 var invalid=0
 for event in unique:
  var x=centre_x+nx*event.d
  var y=centre_y+ny*event.d
  var ground=a.core.sample_height(state.source,x,y)
  var current_height=Surface.height(a,x,y)
  var saved_height=Surface.height(b,x,y)
  var g=is_finite(ground)
  var c=is_finite(current_height)
  var s=is_finite(saved_height)
  var status="nodata" if not g else "invalid_design" if not c or not s else "ok"
  if status=="nodata":missing+=1
  elif status=="invalid_design":invalid+=1
  rows.append({"d":event.d,"x":x,"y":y,"ground":ground if g else null,"current":current_height if c else null,"saved":saved_height if s else null,"current_ground":current_height-ground if c and g else null,"saved_ground":saved_height-ground if s and g else null,"delta":current_height-saved_height if c and s else null,"status":status,"events":"|".join(event.tags)})
 return {"ok":true,"rows":rows,"name":state.name,"station":station,"centre_x":centre_x,"centre_y":centre_y,"normal_x":nx,"normal_y":ny,"half":half,"step":step,"current_settings":settings(state.current),"saved_settings":settings(state.saved),"missing":missing,"invalid":invalid,"ms":(Time.get_ticks_usec()-started)/1000.0}
