extends "res://scripts/profile_comparison_window.gd"
const CrossComparison=preload("res://scripts/section_comparison.gd")
const CROSS_COLUMNS=["saved_name","comparison_basis","station_m","centre_local_east_m","centre_local_south_m","normal_east","normal_south","half_width_m","lateral_step_m","current_width_m","current_offset_m","current_left_down_pct","current_right_down_pct","current_fill_slope_hv","current_cut_slope_hv","saved_width_m","saved_offset_m","saved_left_down_pct","saved_right_down_pct","saved_fill_slope_hv","saved_cut_slope_hv","offset_m","local_east_m","local_south_m","ground_elevation_m","current_design_elevation_m","saved_design_elevation_m","current_minus_ground_m","saved_minus_ground_m","current_minus_saved_m","status","events"]
var reach: SpinBox
var centre_button: Button
const TABLE_HEADER="오프셋(m) | 로컬 동/남(m) | 원지반 | 현재 설계면 | 보관 설계면 | 현재−지반 | 보관−지반 | Δ현재−보관 | 상태 | 경계"

func _ready():
 super._ready()
 title="현재 횡단선의 원지반·대안 설계면 표"
 settings.get_child(0).text="횡단 간격(m)"
 interval.max_value=50
 interval.value=1
 var label=Label.new()
 label.text="조사 반폭(m)"
 settings.add_child(label)
 reach=SpinBox.new()
 reach.min_value=5
 reach.max_value=10000
 reach.step=1
 reach.value=100
 reach.value_changed.connect(func(_value):invalidate())
 settings.add_child(reach)
 settings.move_child(label,2)
 settings.move_child(reach,3)
 centre_button=page_button(settings,"현재 중심 보기",focus_centre)
 centre_button.disabled=true
 var header=Label.new()
 header.text=TABLE_HEADER
 header.tooltip_text=TABLE_HEADER
 header.clip_text=true
 header.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
 var root=table.get_parent()
 root.add_child(header)
 root.move_child(header,root.get_child_count()-2)
 hint.text="현재 횡단선의 동일 좌표 기준 · 오프셋 음수: 현재 노선 좌측 · Δ=현재−보관
보관 영향 밖은 원지반 · 면적/수량 계산 아님 · 측점/설계/선택/조건 변경 후 다시 산출"

func start_calculation():
 if worker!=null:
  status.text="이전 산출 종료 후 다시 산출하세요."
  return
 var state=snapshot_provider.call()
 invalidate()
 if not state.ok:
  status.text=state.error
  return
 requested_revision=state.revision
 requested_generation=generation
 status.text="STA %.3f / %s 횡단선 비교 산출 중" % [state.station,state.name]
 worker=Thread.new()
 if worker.start(CrossComparison.calculate.bind(state,interval.value,reach.value))!=OK:
  worker=null
  status.text="작업 스레드를 시작하지 못했습니다."

func _process(_delta):
 if worker==null or worker.is_alive():return
 var completed=worker.wait_to_finish()
 worker=null
 if requested_revision!=revision_provider.call() or requested_generation!=generation:
  status.text="측점·설계·선택·조건 변경 전 결과를 버렸습니다. 다시 산출하세요."
  return
 if not completed.ok:
  status.text="횡단 표 실패: "+str(completed.get("error","unknown"))
  return
 result=completed
 result_revision=requested_revision
 csv_button.disabled=false
 status.text="STA %.3fm · 보관 %s · ±%.1fm / %.2fm · %d표본 / 결측 %d / 설계면 오류 %d · %.2fms" % [result.station,result.name,result.half,result.step,result.rows.size(),result.missing,result.invalid,result.ms]
 centre_button.disabled=false
 focus_centre()

func show_page():
 if result.is_empty():return
 page=clampi(page,0,(result.rows.size()-1)/PAGE_SIZE)
 var first=page*PAGE_SIZE
 var end=min(first+PAGE_SIZE,result.rows.size())
 previous_button.disabled=page==0
 next_button.disabled=end==result.rows.size()
 page_label.text="%d~%d / %d표본 · CSV는 전체 결과 저장" % [first+1,end,result.rows.size()]
 var lines=PackedStringArray()
 for i in range(first,end):
  var row=result.rows[i]
  lines.append("%.3f | %.3f / %.3f | %s | %s | %s | %s | %s | %s | %s | %s" % [row.d,row.x,row.y,display_number(row.ground),display_number(row.current),display_number(row.saved),display_number(row.current_ground),display_number(row.saved_ground),display_number(row.delta),"결측/경계" if row.status=="nodata" else "설계면 오류" if row.status=="invalid_design" else "유효",cross_events(row.events)])
 setting_table=true
 table.text="\n".join(lines)
 table.set_caret_line(0)
 setting_table=false

func select_row():
 pass # All rows belong to one fixed current section plane.

static func cross_events(raw):
 var labels=PackedStringArray()
 var titles={"left_bound":"조사 좌끝","right_bound":"조사 우끝","regular":"정규","current_center":"현재 중심","current_left_edge":"현재 좌단","current_right_edge":"현재 우단"}
 for tag in raw.split("|"):labels.append(titles.get(tag,tag))
 return "/".join(labels)

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
 file.store_csv_line(PackedStringArray(CROSS_COLUMNS))
 for row in result.rows:
  var values=[result.name,"current_section_world_coordinates",result.station,result.centre_x,result.centre_y,result.normal_x,result.normal_y,result.half,result.step]
  values.append_array(result.current_settings)
  values.append_array(result.saved_settings)
  values.append_array([row.d,row.x,row.y,row.ground,row.current,row.saved,row.current_ground,row.saved_ground,row.delta,row.status,row.events])
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
 status.text="횡단 표 CSV 저장 완료 · 미산출 표고/차이는 빈 셀입니다."
 return true


func invalidate():
 super.invalidate()
 if centre_button!=null:centre_button.disabled=true

func focus_centre():
 if result.is_empty():return
 for index in range(result.rows.size()):
  if result.rows[index].d==0:
   page=index/PAGE_SIZE
   show_page()
   table.set_caret_line(index%PAGE_SIZE)
   table.center_viewport_to_caret()
   return
