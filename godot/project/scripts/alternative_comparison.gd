extends "res://scripts/earthwork_report.gd"
const Model=preload("res://scripts/road_model.gd")
const Earthwork=preload("res://scripts/earthwork_report.gd")
const Token=preload("res://scripts/comparison_token.gd")
const COLUMNS=["name","baseline_name","method","status","length_m","cut_m3","fill_m3","cut_minus_fill_m3","coverage_ratio","covered_length_m","total_length_m","invalid_sections","excluded_intervals","cut_delta_from_first_m3","fill_delta_from_first_m3","station_step_m","half_width_m","lateral_step_m","width_m","offset_m","left_down_pct","right_down_pct","fill_slope_hv","cut_slope_hv","detail"]
var token

func _ready():
 super._ready()
 title="보관 대안 토공량 비교"
 note.text="평균단면법 · 첫 대안 기준 차이는 양쪽 모두 전 구간 완료 시 표시 · 부분합은 유효 길이와 함께 확인하세요."
 note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 var stop=Button.new()
 stop.text="중단"
 stop.pressed.connect(func():
  if worker==null:
   status.text="계산 중인 작업이 없습니다."
   return
  if token!=null:token.cancel()
  status.text="현재 대안 계산 후 중단합니다.")
 interval.get_parent().add_child(stop)
 summary.text="보관 대안을 같은 조사 조건으로 계산합니다."
 csv_dialog.filters=PackedStringArray(["*.csv ; Alternative earthwork comparison"])

func invalidate():
 if token!=null:token.cancel()
 super.invalidate()

func start_calculation():
 if worker!=null:
  status.text="기존 작업 종료를 기다린 뒤 다시 계산하세요."
  return
 var state=snapshot_provider.call()
 invalidate()
 requested_revision=state.revision
 requested_generation=generation
 token=Token.new()
 worker=Thread.new()
 if worker.start(calculate_comparison.bind(state,interval.value,reach.value,lateral.value,token))!=OK:
  worker=null
  status.text="작업 스레드를 시작하지 못했습니다."

static func calculate_comparison(state,step,half_width,lateral_step,cancellation=null):
 var started=Time.get_ticks_usec()
 if not is_finite(step) or not is_finite(half_width) or not is_finite(lateral_step) or step<1 or step>1000 or half_width<5 or half_width>10000 or lateral_step<0.1 or lateral_step>50:return {"ok":false,"error":"비교 조사 조건이 범위를 벗어났습니다."}
 if not state.entries is Array or state.entries.is_empty() or state.entries.size()>20:return {"ok":false,"error":"대안을 1~20개 보관한 후 계산하세요."}
 var rows=[]
 for i in range(state.entries.size()):
  if cancellation!=null:
   if cancellation.is_cancelled():return {"ok":false,"cancelled":true}
   cancellation.progress(i,state.entries.size(),state.entries[i].name)
  var entry=state.entries[i]
  var model=Model.new()
  model.terrain=state.terrain
  model.source=state.source
  var error=model.restore(entry.design)
  var report={"ok":false,"error":error}
  if error=="":report=Earthwork.calculate_job(model.snapshot(),step,half_width,lateral_step)
  var nodata=0
  var unclosed=0
  for section in report.get("sections",[]):
   if section.status=="nodata":nodata+=1
   elif section.status=="unclosed":unclosed+=1
  var detail=str(report.get("error",""))
  if nodata+unclosed>0:detail="DEM 결측/경계 %d · 사면 미접속 %d" % [nodata,unclosed]
  var covered=report.get("covered_length")
  var has_volume=report.ok and report.get("included_intervals",0)>0
  var complete=has_volume and report.get("complete",false)
  rows.append({"name":entry.name,"status":"error" if not report.ok else "complete" if complete else "partial" if has_volume else "missing","length":model.length() if error=="" else null,"cut":report.get("cut_volume") if has_volume else null,"fill":report.get("fill_volume") if has_volume else null,"net":report.get("net_cut_minus_fill") if has_volume else null,"coverage":report.get("coverage"),"covered":covered,"total":report.get("total_length",model.length() if error=="" else null),"invalid":report.get("invalid_sections"),"excluded":report.get("excluded_intervals"),"cut_delta":null,"fill_delta":null,"width":model.road_width,"offset":model.offset,"left":model.left_fall,"right":model.right_fall,"fill_slope":model.slope,"cut_slope":model.cut_slope,"error":detail})
 if cancellation!=null and cancellation.is_cancelled():return {"ok":false,"cancelled":true}
 if rows[0].status=="complete":
  for row in rows:
   if row.status=="complete":
    row.cut_delta=row.cut-rows[0].cut
    row.fill_delta=row.fill-rows[0].fill
 if cancellation!=null:cancellation.progress(rows.size(),rows.size(),"")
 return {"ok":true,"rows":rows,"step":step,"half_width":half_width,"lateral_step":lateral_step,"ms":(Time.get_ticks_usec()-started)/1000.0}

func _process(_delta):
 if worker==null:return
 if worker.is_alive():
  if token!=null:
   var p=token.read()
   status.text=("현재 대안 완료 후 중단 · " if p.cancelled else "계산 중 · ")+"완료 %d/%d · %s" % [p.index,p.total,p.name]
  return
 var completed=worker.wait_to_finish()
 worker=null
 if requested_revision!=revision_provider.call() or requested_generation!=generation:
  status.text="대안·설계·조건 변경 전 결과를 버렸습니다. 다시 계산하세요."
  return
 if completed.get("cancelled",false) or (token!=null and token.is_cancelled()):
  status.text="비교 계산을 중단했습니다. 미완성 결과는 내보내지 않습니다."
  return
 if not completed.ok:
  status.text="비교 실패: "+str(completed.get("error","unknown"))
  return
 result=completed
 result_revision=requested_revision
 csv_button.disabled=false
 status.text="%d개 대안 · %.1fms · 같은 측점/횡단 간격과 조사 반폭 적용" % [result.rows.size(),result.ms]
 summary.text="기준: %s · 첫 대안 대비 차이는 전 구간 완료끼리만 표시 · 모든 수량 단위 m³" % result.rows[0].name
 var counts={"complete":0,"partial":0,"missing":0,"error":0}
 for row in result.rows:counts[row.status]+=1
 summary.text+="\n완료 %d / 부분합 %d / 미산출 %d / 오류 %d" % [counts.complete,counts.partial,counts.missing,counts.error]
 var labels={"complete":"전 구간","partial":"유효 구간 부분합","missing":"미산출","error":"계산 오류"}
 var lines=PackedStringArray(["대안 | 길이(m) | 상태 | 절토(m³) | 성토(m³) | 절토−성토 | 유효/전체 길이(m,%) | Δ절토 | Δ성토 | 제외 구간 | 사유"])
 for row in result.rows:
  lines.append("%s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s" % [row.name,number_text(row.length),labels[row.status],number_text(row.cut),number_text(row.fill),number_text(row.net),coverage_text(row),number_text(row.cut_delta),number_text(row.fill_delta),"NA" if row.excluded==null else str(row.excluded),row.error])
 table.text="\n".join(lines)

static func coverage_text(row):
 if row.coverage==null or row.covered==null or row.total==null:return "NA"
 return "%.1f/%.1f (%.2f%%)" % [row.covered,row.total,row.coverage*100]

func select_row():
 pass # Comparison rows are different designs, not stations of the active design.

func export_csv(path):
 if result.is_empty() or result_revision!=revision_provider.call():
  invalidate()
  return false
 var temporary=path+".tmp_"+str(Time.get_ticks_usec())
 var file=FileAccess.open(temporary,FileAccess.WRITE)
 if file==null:
  status.text="CSV 파일을 열지 못했습니다."
  return false
 file.store_buffer(PackedByteArray([239,187,191]))
 file.store_csv_line(PackedStringArray(COLUMNS))
 for row in result.rows:
  var values=[row.name,result.rows[0].name,"average_end_area",row.status,row.length,row.cut,row.fill,row.net,row.coverage,row.covered,row.total,row.invalid,row.excluded,row.cut_delta,row.fill_delta,result.step,result.half_width,result.lateral_step,row.width,row.offset,row.left,row.right,row.fill_slope,row.cut_slope,row.error]
  var cells=PackedStringArray()
  for value in values:cells.append("" if value==null else str(value))
  file.store_csv_line(cells)
 file.flush()
 var error=file.get_error()
 file.close()
 if error!=OK or DirAccess.rename_absolute(temporary,path)!=OK:
  DirAccess.remove_absolute(temporary)
  status.text="CSV 저장 실패 · 기존 파일은 보존됩니다."
  return false
 status.text="대안 비교 CSV 저장 완료 · NA는 빈 셀로 기록했습니다."
 return true

func _exit_tree():
 if token!=null:token.cancel()
 super._exit_tree()
