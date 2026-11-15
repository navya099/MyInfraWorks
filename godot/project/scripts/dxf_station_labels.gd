extends RefCounted
const MAX_ANNOTATIONS=2000

static func readable_rotation(heading):
 var rotation=fposmod(-rad_to_deg(heading)+180.0,360.0)-180.0
 if rotation>90:rotation-=180
 elif rotation< -90:rotation+=180
 return rotation

static func build(alignment,length,width,offset,step,ox,oy,text_height=0.0,begin=0.0,finish=-1.0):
 if not is_finite(width) or width<=0 or not is_finite(offset):return {"ok":false,"error":"측점 주석의 도로 폭/보정고가 유효하지 않습니다."}
 if finish<0:finish=length
 var first=ceili(begin/float(step))
 var last=floori(finish/float(step))
 if last-first+1>MAX_ANNOTATIONS:return {"ok":false,"error":"측점 주석이 2000개를 넘습니다. 주석 간격을 늘리세요."}
 var stations=[begin]
 for i in range(first,last+1):
  var station=i*step
  if station-begin>=0.001 and finish-station>=0.001:stations.append(station)
 stations.append(finish)
 if stations.size()>MAX_ANNOTATIONS:return {"ok":false,"error":"측점 주석이 2000개를 넘습니다. 주석 간격을 늘리세요."}
 var annotations=[]
 var half=max(5.0,width*0.75)
 var height=text_height if text_height>0 else clamp(width/6.0,1.0,20.0)
 for station in stations:
  var at=alignment.sample(station)
  var x=ox+at.x
  var y=oy-at.y
  var z=at.elevation+offset
  var nx=-sin(at.heading)
  var ny=-cos(at.heading)
  var rotation=readable_rotation(at.heading)
  var tx=x+nx*(half+height)
  var ty=y+ny*(half+height)
  var label="STA %.3f" % station
  var tick=[[x-nx*half,y-ny*half,z],[x+nx*half,y+ny*half,z]]
  var bounds=tick.duplicate(true)
  var radians=deg_to_rad(rotation)
  var extent=(label.length()+2)*height
  for u in [0.0,extent]:
   for v in [0.0,height]:bounds.append([tx+cos(radians)*u-sin(radians)*v,ty+sin(radians)*u+cos(radians)*v,z])
  annotations.append({"station":station,"tick":tick,"x":tx,"y":ty,"z":z,"rotation":rotation,"height":height,"label":label,"bounds":bounds})
 return {"ok":true,"annotations":annotations}
