extends RefCounted

static func fail(message):
 return {"ok":false,"error":message}

static func quantity(value):
 return (typeof(value)==TYPE_FLOAT or typeof(value)==TYPE_INT) and is_finite(value) and value>=0

static func calculate(report,begin,finish):
 var started=Time.get_ticks_usec()
 if not is_finite(begin) or not is_finite(finish) or begin<0 or finish<=begin:
  return fail("시작·끝 측점은 유한한 숫자이며 0 ≤ 시작 < 끝이어야 합니다.")
 if not report.get("ok",false) or not report.get("sections") is Array or report.sections.size()<2:
  return fail("유효한 토공량 계산 결과가 필요합니다.")
 var sections=report.sections
 for i in range(sections.size()):
  if not quantity(sections[i].get("station")) or (i>0 and sections[i].station<=sections[i-1].station):
   return fail("원본 수량 측점이 올바르지 않습니다.")
 if begin<sections[0].station or finish>sections[-1].station:
  return fail("집계 범위는 원본 조사 측점 범위 안에 있어야 합니다.")
 var rows=[]
 var cut=0.0
 var fill=0.0
 var covered=0.0
 var included=0
 var excluded=0
 for i in range(1,sections.size()):
  var previous=sections[i-1]
  var current=sections[i]
  var a=max(begin,previous.station)
  var b=min(finish,current.station)
  if b<=a:continue
  var row={"start":a,"end":b,"length":b-a,"source_start":previous.station,"source_end":current.station,"status":"excluded","cut":null,"fill":null,"cut_start":null,"cut_end":null,"fill_start":null,"fill_end":null,"detail":""}
  var state=current.get("interval_status","")
  if state=="included":
   for section in [previous,current]:
    if section.get("status")!="ok" or not quantity(section.get("cut_area")) or not quantity(section.get("fill_area")):
     return fail("유효 구간의 원본 단면적이 올바르지 않습니다.")
   var length=float(current.station)-float(previous.station)
   var left=(a-previous.station)/length
   var right=(b-previous.station)/length
   row.cut_start=lerpf(previous.cut_area,current.cut_area,left)
   row.cut_end=lerpf(previous.cut_area,current.cut_area,right)
   row.fill_start=lerpf(previous.fill_area,current.fill_area,left)
   row.fill_end=lerpf(previous.fill_area,current.fill_area,right)
   row.cut=(row.cut_start+row.cut_end)*row.length/2.0
   row.fill=(row.fill_start+row.fill_end)*row.length/2.0
   if not quantity(row.cut) or not quantity(row.fill):return fail("집계 수량이 유효한 숫자 범위를 벗어났습니다.")
   row.status="included"
   cut+=row.cut
   fill+=row.fill
   covered+=row.length
   included+=1
  elif state=="excluded":
   excluded+=1
   row.detail="%s / %s" % [previous.get("status","unknown"),current.get("status","unknown")]
  else:
   return fail("원본 구간 상태가 올바르지 않습니다.")
  rows.append(row)
 if not quantity(cut) or not quantity(fill):return fail("합계 수량이 유효한 숫자 범위를 벗어났습니다.")
 var length=finish-begin
 var complete=excluded==0 and included>0
 return {"ok":true,"rows":rows,"start":begin,"end":finish,"length":length,"covered":covered,"coverage":covered/length,"status":"complete" if complete else "partial" if included>0 else "missing","cut":cut if included>0 else null,"fill":fill if included>0 else null,"net":cut-fill if included>0 else null,"included":included,"excluded":excluded,"ms":(Time.get_ticks_usec()-started)/1000.0}
