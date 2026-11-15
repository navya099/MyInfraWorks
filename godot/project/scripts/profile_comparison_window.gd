extends "res://scripts/station_table.gd"
const Comparison=preload("res://scripts/profile_comparison.gd")
const PROFILE_COLUMNS=["saved_name","comparison_basis","station_step_m","current_length_m","saved_length_m","common_length_m","current_offset_m","saved_offset_m","station_m","current_elevation_m","saved_elevation_m","current_minus_saved_m","current_local_east_m","current_local_south_m","saved_local_east_m","saved_local_south_m","horizontal_separation_m","current_grade_pct","saved_grade_pct","events"]
const PAGE_SIZE=200
var page=0
var previous_button: Button
var next_button: Button
var page_label: Label

func _ready():
 super._ready()
 title="현재·보관 대안 측점별 계획고 비교"
 hint.text="같은 절대 STA 기준 · Δ=현재−보관 · 좌표는 로컬 동/남 · 수평 이격은 같은 STA 두 점 사이 거리
동일 지점 비교나 최단 이격/토공량 아님 · DEM 조회 없음 · 행 선택: 현재 측점 이동"
 var paging=HBoxContainer.new()
 var root=table.get_parent()
 root.add_child(paging)
 root.move_child(paging,root.get_child_count()-2)
 previous_button=page_button(paging,"이전 페이지",func():page-=1;show_page())
 next_button=page_button(paging,"다음 페이지",func():page+=1;show_page())
 page_label=Label.new()
 paging.add_child(page_label)
 invalidate()

func page_button(parent,text,action):
 var button=Button.new()
 button.text=text
 button.pressed.connect(action)
 parent.add_child(button)
 return button

func invalidate():
 super.invalidate()
 page=0
 if previous_button!=null:previous_button.disabled=true
 if next_button!=null:next_button.disabled=true
 if page_label!=null:page_label.text=""

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
 status.text="현재 / %s 비교 산출 중" % state.name
 worker=Thread.new()
 if worker.start(Comparison.calculate.bind(state.current,state.saved,state.name,interval.value))!=OK:
  worker=null
  status.text="작업 스레드를 시작하지 못했습니다."

func _process(_delta):
 if worker==null or worker.is_alive():return
 var completed=worker.wait_to_finish()
 worker=null
 if requested_revision!=revision_provider.call() or requested_generation!=generation:
  status.text="설계·보관본 선택·목록·간격 변경 전 결과를 버렸습니다. 다시 산출하세요."
  return
 if not completed.ok:
  status.text="비교 실패: "+str(completed.get("error","unknown"))
  return
 result=completed
 result_revision=requested_revision
 csv_button.disabled=false
 status.text="보관: %s · 공통 %.3fm / 현재 %.3fm / 보관 %.3fm · %d측점 · %.1fms" % [result.name,result.common_length,result.current_length,result.saved_length,result.rows.size(),result.ms]
 show_page()

func show_page():
 if result.is_empty():return
 page=clampi(page,0,(result.rows.size()-1)/PAGE_SIZE)
 var first=page*PAGE_SIZE
 var end=min(first+PAGE_SIZE,result.rows.size())
 previous_button.disabled=page==0
 next_button.disabled=end==result.rows.size()
 page_label.text="%d~%d / %d측점 · CSV는 전체 결과 저장" % [first+1,end,result.rows.size()]
 var lines=PackedStringArray(["STA(m) | 현재 계획고 | 보관 계획고 | Δ현재−보관 | 수평 이격(m) | 현재 동/남(m) | 보관 동/남(m) | 현재/보관 구배(%) | 경계"])
 for i in range(first,end):
  var row=result.rows[i]
  lines.append("%.3f | %.3f | %.3f | %.3f | %.3f | %.3f / %.3f | %.3f / %.3f | %.3f / %.3f | %s" % [row.station,row.current_height,row.saved_height,row.delta,row.separation,row.current_x,row.current_y,row.saved_x,row.saved_y,row.current_grade,row.saved_grade,comparison_events(row.events)])
 setting_table=true
 table.text="\n".join(lines)
 table.set_caret_line(0)
 setting_table=false

func select_row():
 if setting_table or result.is_empty() or result_revision!=revision_provider.call():return
 var index=page*PAGE_SIZE+table.get_caret_line()-1
 if table.get_caret_line()>0 and index<result.rows.size():station_selected.emit(result.rows[index].station)

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
 file.store_csv_line(PackedStringArray(PROFILE_COLUMNS))
 for row in result.rows:
  var cells=PackedStringArray()
  for value in [result.name,"same_absolute_station",result.step,result.current_length,result.saved_length,result.common_length,result.current_offset,result.saved_offset,row.station,row.current_height,row.saved_height,row.delta,row.current_x,row.current_y,row.saved_x,row.saved_y,row.separation,row.current_grade,row.saved_grade,row.events]:cells.append(str(value))
  file.store_csv_line(cells)
 file.flush()
 var error=file.get_error()
 file.close()
 if error!=OK or DirAccess.rename_absolute(temporary,path)!=OK:
  DirAccess.remove_absolute(temporary)
  status.text="CSV 저장 실패 · 기존 파일은 보존됩니다."
  return false
 status.text="계획고 비교 CSV 저장 완료 · 같은 STA 기준이며 동일 지점 비교는 아닙니다."
 return true


static func comparison_events(raw):
 var labels=PackedStringArray()
 var titles={"start":"시점","common_end":"공통 끝","regular":"정규","PI":"PI","PVI":"PVI","BVC":"BVC","EVC":"EVC","geometry_boundary":"평면 경계"}
 for tag in raw.split("|"):
  var prefix="현재 " if tag.begins_with("current_") else "보관 " if tag.begins_with("saved_") else ""
  var key=tag.trim_prefix("current_").trim_prefix("saved_")
  labels.append(prefix+titles.get(key,key))
 return "/".join(labels)
