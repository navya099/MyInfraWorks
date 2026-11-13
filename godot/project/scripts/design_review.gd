extends RefCounted
# User-entered comparison limits; these are examples, not a design standard.
const DEFAULT_LIMITS={"min_r":300.0,"min_ls":50.0,"max_grade":5.0,"min_k_crest":20.0,"min_k_sag":20.0}
const EPS=1e-8

static func issue(code,severity,kind,index,start,end,value,limit,unit,detail):
 return {"code":code,"severity":severity,"kind":kind,"index":index,"start":start,"end":end,"station":(start+end)/2.0,"value":value,"limit":limit,"unit":unit,"detail":detail}

static func grade_issues(rows,start,end,g0,g1,limit,kind,index):
 if limit<=0 or end-start<=EPS:return
 for sign_value in [-1.0,1.0]:
  var v0=sign_value*g0
  var v1=sign_value*g1
  if max(v0,v1)<=limit+EPS:continue
  var lo=0.0
  var hi=1.0
  if v0<=limit:lo=(limit-v0)/(v1-v0)
  if v1<=limit:hi=(limit-v0)/(v1-v0)
  var a=lerp(start,end,lo)
  var b=lerp(start,end,hi)
  rows.append(issue("GRADE_MAX","limit",kind,index,a,b,max(v0,v1),limit,"%",("오르막" if sign_value>0 else "내리막")+" · 실제 구배의 한계 초과 범위(경계값 포함)"))

static func calculate(state,limits):
 var started=Time.get_ticks_usec()
 for key in DEFAULT_LIMITS:
  var value=limits.get(key,null)
  if (typeof(value)!=TYPE_INT and typeof(value)!=TYPE_FLOAT) or not is_finite(float(value)) or value<0:
   return {"ok":false,"error":"검토 기준은 유한한 0 이상의 숫자여야 합니다: "+key}
 var alignment=ClassDB.instantiate("KRoadAlignment")
 var info=alignment.configure_independent(state.pi_route,state.radii,state.spirals,state.pvi_stations,state.pvi_heights,state.pvi_lengths)
 if not info.ok:return info
 if info.length<=0:return {"ok":false,"error":"두 점 이상의 유효한 노선이 필요합니다."}
 var rows=[]
 var curves={}
 for element in info.elements:
  if element.type=="line":continue
  var index=int(element.pi)
  if not curves.has(index):curves[index]=[element.station,element.station+element.length]
  else:curves[index][1]=element.station+element.length
 var checks=0
 for i in range(1,state.pi_route.size()-1):
  var a=state.pi_route[i]-state.pi_route[i-1]
  var b=state.pi_route[i+1]-state.pi_route[i]
  var angle=abs(wrapf(atan2(b.z,b.x)-atan2(a.z,a.x),-PI,PI))
  checks+=1
  if state.radii[i]<=0:
   if angle>1e-7:
    rows.append(issue("H_KINK","warning","PI",i+1,info.pi_stations[i],info.pi_stations[i],rad_to_deg(angle),null,"deg","방향 변화가 있는 R=0 교점 · 평면곡선 미설정"))
   continue
  var span=curves[i]
  if limits.min_r>0:
   checks+=1
   if state.radii[i]+EPS<limits.min_r:rows.append(issue("R_MIN","limit","PI",i+1,span[0],span[1],state.radii[i],limits.min_r,"m","원곡선 반경 < 사용자 최소값"))
  if limits.min_ls>0:
   checks+=1
   if state.spirals[i]+EPS<limits.min_ls:rows.append(issue("LS_MIN","limit","PI",i+1,span[0],span[1],state.spirals[i],limits.min_ls,"m","각 진입·진출 완화곡선 길이 < 사용자 최소값"))
 var stations=info.pvi_stations
 var heights=info.pvi_heights
 var lengths=info.pvi_lengths
 var grades=PackedFloat64Array()
 var max_grade=0.0
 for i in range(stations.size()-1):
  var grade=100.0*(heights[i+1]-heights[i])/(stations[i+1]-stations[i])
  grades.append(grade)
  max_grade=max(max_grade,abs(grade))
  var start=stations[i]+lengths[i]/2.0
  var end=stations[i+1]-lengths[i+1]/2.0
  if limits.max_grade>0 and end-start>EPS:
   checks+=1
   grade_issues(rows,start,end,grade,grade,limits.max_grade,"접선구간",i+1)
 for i in range(1,stations.size()-1):
  var delta=grades[i]-grades[i-1]
  var change=abs(delta)
  checks+=1
  if change<=EPS:continue # No grade change: K is undefined, not zero.
  var start=stations[i]-lengths[i]/2.0
  var end=stations[i]+lengths[i]/2.0
  if lengths[i]<=0:
   rows.append(issue("V_KINK","warning","PVI",i+1,start,end,change,null,"%","구배 변화가 있는 Lv=0 교점 · 종단곡선 미설정"))
   continue
  var key="min_k_crest" if delta<0 else "min_k_sag"
  if limits[key]>0:
   checks+=1
   var k=lengths[i]/change
   if k+EPS<limits[key]:rows.append(issue("K_CREST_MIN" if delta<0 else "K_SAG_MIN","limit","PVI",i+1,start,end,k,limits[key],"m/%",("볼록" if delta<0 else "오목")+" 종단곡선 K=Lv/|구배차(%)| < 사용자 최소값"))
  if limits.max_grade>0:
   checks+=1
   grade_issues(rows,start,end,grades[i-1],grades[i],limits.max_grade,"PVI",i+1)
 rows.sort_custom(func(a,b):
  if a.start==b.start:return a.code<b.code
  return a.start<b.start)
 var violations=0
 for row in rows:
  if row.severity=="limit":violations+=1
 return {"ok":true,"issues":rows,"length":info.length,"checks":checks,"violations":violations,"warnings":rows.size()-violations,"max_grade":max_grade,"limits":limits.duplicate(),"ms":(Time.get_ticks_usec()-started)/1000.0}
