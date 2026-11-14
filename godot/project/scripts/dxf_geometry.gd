extends RefCounted
const MAX_STATIONS=30000

static func has_origin(source):
 return typeof(source.get("OriginX")) in [TYPE_INT,TYPE_FLOAT] and typeof(source.get("OriginY")) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(source.OriginX)) and is_finite(float(source.OriginY))

static func pair(lines,code,value):
 lines.append(str(code))
 lines.append(str(value))

static func calculate_job(snapshot,spacing,coordinate_mode):
 var started=Time.get_ticks_usec()
 if not is_finite(spacing) or spacing<1 or spacing>25:return {"ok":false,"error":"최대 측점 간격은 1~25m입니다."}
 if coordinate_mode not in [0,1]:return {"ok":false,"error":"지원하지 않는 좌표 모드입니다."}
 var projected=coordinate_mode==1
 if projected and not has_origin(snapshot.source):return {"ok":false,"error":"DEM 원점 정보가 없어 EPSG:5179로 내보낼 수 없습니다."}
 var alignment=ClassDB.instantiate("KRoadAlignment")
 var info=alignment.configure_independent(snapshot.pi_route,snapshot.radii,snapshot.spirals,snapshot.pvi_stations,snapshot.pvi_heights,snapshot.pvi_lengths)
 if not info.ok:return info
 if info.length<=0:return {"ok":false,"error":"두 점 이상의 노선이 필요합니다."}
 var count=ceili(info.length/spacing)
 if count+1>MAX_STATIONS:return {"ok":false,"error":"점 수가 너무 많습니다. 간격을 늘리세요."}
 var stations=Array(alignment.sampling_stations())
 for i in range(1,count):stations.append(i*spacing)
 stations.sort()
 var unique=PackedFloat64Array()
 for station in stations:
  if unique.is_empty() or abs(station-unique[-1])>=1e-7:unique.append(station)
 # Retain the exact terminal station even if a regular sample nearly coincides.
 unique[-1]=info.length
 if unique.size()>MAX_STATIONS:return {"ok":false,"error":"선형 분할을 포함해 30000측점을 넘습니다. 간격을 늘리거나 노선을 줄여 주세요."}
 var ox=float(snapshot.source.OriginX) if projected else 0.0
 var oy=float(snapshot.source.OriginY) if projected else 0.0
 var layers=[{"name":"KROAD_CENTER","color":2,"vertices":[]},{"name":"KROAD_LEFT","color":4,"vertices":[]},{"name":"KROAD_RIGHT","color":3,"vertices":[]}]
 var minimum=[INF,INF,INF]
 var maximum=[-INF,-INF,-INF]
 for station in unique:
  var at=alignment.sample(station)
  var nx=-sin(at.heading)
  var ny=cos(at.heading)
  for index in range(3):
   var d=0.0 if index==0 else -snapshot.width/2.0 if index==1 else snapshot.width/2.0
   var fall=snapshot.get("left_fall",0.0) if index==1 else snapshot.get("right_fall",0.0)
   var point=[ox+at.x+nx*d,oy-at.y-ny*d,at.elevation+snapshot.offset-abs(d)*fall/100.0]
   for axis in range(3):
    minimum[axis]=min(minimum[axis],point[axis])
    maximum[axis]=max(maximum[axis],point[axis])
    layers[index].vertices.append(point[axis])
 var lines=PackedStringArray()
 pair(lines,999,"MYINFRAWORKS; UNITS=METERS; CRS="+("EPSG:5179" if projected else "LOCAL_EAST_NORTH")+"; DESIGN_ELEVATIONS; NO_DISPLAY_LIFT")
 pair(lines,0,"SECTION");pair(lines,2,"HEADER")
 pair(lines,9,"$ACADVER");pair(lines,1,"AC1009")
 pair(lines,9,"$LUNITS");pair(lines,70,2)
 pair(lines,9,"$LUPREC");pair(lines,70,6)
 pair(lines,9,"$INSBASE")
 for axis in range(3):pair(lines,10+axis*10,0)
 for bounds in [{"key":"$EXTMIN","value":minimum},{"key":"$EXTMAX","value":maximum}]:
  pair(lines,9,bounds.key)
  for axis in range(3):pair(lines,10+axis*10,"%.9f" % bounds.value[axis])
 pair(lines,0,"ENDSEC")
 pair(lines,0,"SECTION");pair(lines,2,"TABLES")
 pair(lines,0,"TABLE");pair(lines,2,"LTYPE");pair(lines,70,1)
 pair(lines,0,"LTYPE");pair(lines,2,"CONTINUOUS");pair(lines,70,0);pair(lines,3,"Solid line");pair(lines,72,65);pair(lines,73,0);pair(lines,40,0)
 pair(lines,0,"ENDTAB")
 pair(lines,0,"TABLE");pair(lines,2,"LAYER");pair(lines,70,4)
 for layer in [{"name":"0","color":7}]+layers:
  pair(lines,0,"LAYER");pair(lines,2,layer.name);pair(lines,70,0);pair(lines,62,layer.color);pair(lines,6,"CONTINUOUS")
 pair(lines,0,"ENDTAB");pair(lines,0,"ENDSEC")
 pair(lines,0,"SECTION");pair(lines,2,"BLOCKS");pair(lines,0,"ENDSEC")
 pair(lines,0,"SECTION");pair(lines,2,"ENTITIES")
 for layer in layers:
  pair(lines,0,"POLYLINE");pair(lines,8,layer.name);pair(lines,66,1)
  pair(lines,10,0);pair(lines,20,0);pair(lines,30,0);pair(lines,70,8)
  for i in range(0,layer.vertices.size(),3):
   pair(lines,0,"VERTEX");pair(lines,8,layer.name)
   for axis in range(3):pair(lines,10+axis*10,"%.9f" % layer.vertices[i+axis])
   pair(lines,70,32)
  pair(lines,0,"SEQEND");pair(lines,8,layer.name)
 pair(lines,0,"ENDSEC");pair(lines,0,"EOF")
 return {"ok":true,"text":"\n".join(lines)+"\n","stations":unique.size(),"vertices":unique.size()*3,"length":info.length,"spacing":spacing,"crs":"EPSG:5179" if projected else "LOCAL_EAST_NORTH","ms":(Time.get_ticks_usec()-started)/1000.0}
