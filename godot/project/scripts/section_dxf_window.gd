extends "res://scripts/dxf_window.gd"
const CrossDxf=preload("res://scripts/section_dxf_geometry.gd")
var report_button: Button
var report_dialog: FileDialog
var copy_button: Button
var reach: SpinBox
var lateral_step: SpinBox
var columns: SpinBox
var begin_input: LineEdit
var end_input: LineEdit
var range_length=-1.0
var requested_inputs=PackedStringArray()
var extra_input: LineEdit
var include_boundaries: CheckBox
var grid_enabled: CheckBox
var grid_interval: SpinBox
var export_ground: CheckBox
var export_axes: CheckBox
var export_design: CheckBox
var common_datum_enabled: CheckBox
var common_datum_input: SpinBox
var number_sections: CheckBox
var text_height_input: SpinBox
var label_decimals: SpinBox
var chainage_labels: CheckBox
var extras_only: CheckBox

func _ready():
 super._ready()
 title="횡단 DXF 일괄 내보내기"
 copy_button=Button.new()
 copy_button.text="산출 결과 복사"
 copy_button.disabled=true
 copy_button.pressed.connect(copy_result)
 settings.add_child(copy_button)
 report_button=Button.new()
 report_button.text="결과 TXT 저장"
 report_button.disabled=true
 settings.add_child(report_button)
 report_dialog=FileDialog.new()
 report_dialog.access=FileDialog.ACCESS_FILESYSTEM
 report_dialog.file_mode=FileDialog.FILE_MODE_SAVE_FILE
 report_dialog.filters=PackedStringArray(["*.txt ; Cross-section result report"])
 add_child(report_dialog)
 report_button.pressed.connect(func():report_dialog.popup_centered_ratio(0.7))
 report_dialog.file_selected.connect(save_report)
 coordinate_mode.hide()
 interval.min_value=1
 interval.max_value=10000
 interval.value=1000
 settings.get_child(0).text="횡단 측점 간격(m)"
 var extra=HBoxContainer.new()
 var root=table.get_parent()
 root.add_child(extra)
 root.move_child(extra,1)
 reach=number(extra,"조사 반폭(m)",100,5,10000,1)
 lateral_step=number(extra,"횡단 간격(m)",2,0.1,50,0.1)
 columns=number(extra,"배치 열 수",3,1,8,1)
 grid_enabled=CheckBox.new()
 grid_enabled.text="격자·표고 눈금"
 extra.add_child(grid_enabled)
 grid_interval=number(extra,"격자(m)",10,0.5,1000,0.5)
 grid_interval.editable=false
 grid_enabled.toggled.connect(func(enabled):grid_interval.editable=enabled;invalidate())
 var range_row=HBoxContainer.new()
 root.add_child(range_row)
 root.move_child(range_row,2)
 for title_text in ["시작 STA(m)","끝 STA(m)"]:
  var label=Label.new()
  label.text=title_text
  range_row.add_child(label)
  var input=LineEdit.new()
  input.custom_minimum_size.x=150
  input.max_length=32
  input.text_changed.connect(func(_text):invalidate())
  range_row.add_child(input)
  if begin_input==null:begin_input=input
  else:end_input=input
 var full_button=Button.new()
 full_button.text="전체 범위"
 full_button.pressed.connect(full_range)
 range_row.add_child(full_button)
 include_boundaries=CheckBox.new()
 include_boundaries.text="주요 선형 경계 포함"
 include_boundaries.toggled.connect(func(_enabled):invalidate())
 range_row.add_child(include_boundaries)
 var style_row=HBoxContainer.new()
 root.add_child(style_row)
 chainage_labels=CheckBox.new()
 chainage_labels.text="STA km+m 표기"
 chainage_labels.toggled.connect(func(_enabled):invalidate())
 style_row.add_child(chainage_labels)
 label_decimals=number(style_row,"STA 소수",3,0,3,1)
 var extra_row=HBoxContainer.new()
 root.add_child(extra_row)
 root.move_child(extra_row,3)
 var extra_label=Label.new()
 extra_label.text="추가 STA(m)"
 extras_only=CheckBox.new()
 extras_only.text="추가 STA만 출력"
 extras_only.toggled.connect(func(enabled):
  interval.editable=not enabled
  include_boundaries.disabled=enabled
  invalidate())
 extra_row.add_child(extras_only)
 extra_row.add_child(extra_label)
 extra_input=LineEdit.new()
 extra_input.placeholder_text="예: 123.45, 567.89 · 쉼표 구분 · 최대 100개"
 extra_input.max_length=3000
 extra_input.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 extra_input.text_changed.connect(func(_text):invalidate())
 extra_row.add_child(extra_input)
 var current_button=Button.new()
 current_button.text="현재 STA 추가"
 current_button.pressed.connect(add_current_station)
 extra_row.add_child(current_button)
 var clear_button=Button.new()
 clear_button.text="비우기"
 clear_button.pressed.connect(func():extra_input.text="";invalidate())
 extra_row.add_child(clear_button)
 text_height_input=number(style_row,"글자(m, 0=자동)",0,0,5,0.1)
 number_sections=CheckBox.new()
 number_sections.text="횡단 번호"
 number_sections.toggled.connect(func(_enabled):invalidate())
 style_row.add_child(number_sections)
 var datum_row=HBoxContainer.new()
 root.add_child(datum_row)
 root.move_child(style_row,4)
 root.move_child(datum_row,5)
 common_datum_enabled=CheckBox.new()
 common_datum_enabled.text="공통 DATUM 사용"
 datum_row.add_child(common_datum_enabled)
 common_datum_input=number(datum_row,"기준표고(m)",0,-100000,100000,0.1)
 common_datum_input.editable=false
 for title_text in ["원지반 출력","설계선 출력"]:
  var toggle=CheckBox.new()
  toggle.text=title_text
  toggle.button_pressed=true
  toggle.toggled.connect(func(_enabled):invalidate())
  datum_row.add_child(toggle)
  if export_ground==null:export_ground=toggle
  else:export_design=toggle
 export_axes=CheckBox.new()
 export_axes.text="축선 출력"
 export_axes.button_pressed=true
 export_axes.toggled.connect(func(_enabled):invalidate())
 datum_row.add_child(export_axes)
 common_datum_enabled.toggled.connect(func(enabled):common_datum_input.editable=enabled;invalidate())
 var reset_button=Button.new()
 reset_button.text="출력 설정 초기화"
 reset_button.pressed.connect(reset_settings)
 style_row.add_child(reset_button)
 csv_dialog.filters=PackedStringArray(["*.dxf ; Cross-section layout DXF"])
 hint.text="기본: 구간 양 끝+정규 측점+추가 STA / 추가 STA만 출력: 입력한 위치만 · 도면 단위 m · H:V=1:1 · 원지반/설계 별도 레이어
2D 도면 배치이며 지도/EPSG 좌표 아님 · 결측은 선 끊기 · CAD 가져오기 단위 m 지정"

func number(parent,title,value,minimum,maximum,step):
 var label=Label.new()
 label.text=title
 parent.add_child(label)
 var spin=SpinBox.new()
 spin.min_value=minimum
 spin.max_value=maximum
 spin.step=step
 spin.value=value
 spin.value_changed.connect(func(_value):invalidate())
 parent.add_child(spin)
 return spin

func full_range():
 var state=snapshot_provider.call()
 begin_input.text="0"
 end_input.text=str(state.length)
 range_length=state.length
 invalidate()

func add_current_station():
 var state=snapshot_provider.call()
 if not begin_input.text.is_valid_float() or not end_input.text.is_valid_float():
  status.text="출력 구간을 먼저 지정하세요."
  return
 var station=state.station
 var begin=begin_input.text.to_float()
 var finish=state.length if end_input.text==str(state.length) else end_input.text.to_float()
 if not is_finite(begin) or not is_finite(finish) or begin<0 or finish>state.length or finish-begin<1:
  status.text="유효한 출력 구간을 먼저 지정하세요."
  return
 if not is_finite(station) or station<begin or station>finish:
  status.text="현재 STA가 출력 구간 밖입니다."
  return
 var parsed=CrossDxf.parse_extra(extra_input.text)
 if not parsed.ok:
  status.text=parsed.error
  return
 if parsed.stations.size()>=100:
  status.text="추가 STA는 최대 100개입니다."
  return
 extra_input.text+=(", " if not extra_input.text.strip_edges().is_empty() else "")+str(station)
 invalidate()

func input_signature():
 return PackedStringArray([begin_input.text,end_input.text,str(interval.value),str(reach.value),str(lateral_step.value),str(columns.value),extra_input.text,str(include_boundaries.button_pressed),str(grid_enabled.button_pressed),str(grid_interval.value),str(extras_only.button_pressed),str(chainage_labels.button_pressed),str(label_decimals.value),str(text_height_input.value),str(number_sections.button_pressed),str(common_datum_enabled.button_pressed),str(common_datum_input.value),str(export_ground.button_pressed),str(export_design.button_pressed),str(export_axes.button_pressed)])

func open_export():
 if range_length!=snapshot_provider.call().length:full_range()
 popup_centered(Vector2i(1250,650))

func start_calculation():
 if worker!=null:
  status.text="이전 산출 종료 후 다시 산출하세요."
  return
 var state=snapshot_provider.call()
 invalidate()
 if not begin_input.text.is_valid_float() or not end_input.text.is_valid_float():
  status.text="시작·끝 STA를 숫자로 입력하세요."
  return
 var bounds={"begin":begin_input.text.to_float(),"end":state.length if end_input.text==str(state.length) else end_input.text.to_float()}
 requested_inputs=input_signature()
 requested_revision=state.revision
 requested_generation=generation
 status.text="횡단 DXF 산출 중 · 최대 500횡단 / 전체 100000표본"
 worker=Thread.new()
 if worker.start(CrossDxf.calculate_job.bind(state.snapshot,interval.value,reach.value,lateral_step.value,int(columns.value),bounds,extra_input.text,include_boundaries.button_pressed,grid_interval.value if grid_enabled.button_pressed else 0.0,extras_only.button_pressed,chainage_labels.button_pressed,int(label_decimals.value),text_height_input.value,number_sections.button_pressed,common_datum_input.value if common_datum_enabled.button_pressed else null,export_ground.button_pressed,export_design.button_pressed,export_axes.button_pressed))!=OK:
  worker=null
  status.text="작업 스레드를 시작하지 못했습니다."

func _process(_delta):
 if worker==null or worker.is_alive():return
 var completed=worker.wait_to_finish()
 worker=null
 if requested_revision!=revision_provider.call() or requested_generation!=generation or requested_inputs!=input_signature():
  status.text="설계/DEM/조건 변경 전 횡단 도면을 버렸습니다. 다시 산출하세요."
  return
 if not completed.ok:
  status.text="횡단 DXF 실패: "+str(completed.get("error","unknown"))
  return
 result=completed
 result_revision=requested_revision
 csv_button.disabled=false
 copy_button.disabled=false
 report_button.disabled=false
 status.text="%d횡단 / %d표본 · 원지반 결측 %d · %.1fms" % [result.sections.size(),result.samples,result.missing,result.ms]
 var lines=PackedStringArray(["주요 경계 %s · 경계 포함 횡단 %d개" % ["포함" if result.include_boundaries else "제외",result.boundary_sections],"추가 STA 입력 %d개 · 중복 병합 후 총 %d횡단" % [result.extra_requested,result.sections.size()],"출력 STA %.3f~%.3fm · 구간 길이 %.3fm · 원래 STA 유지" % [result.begin,result.end,result.end-result.begin],"DXF R12 ASCII / H:V 1:1 / Z=0 배치 / CAD 단위 m", "녹색 KROAD_SEC_GROUND / 노랑 KROAD_SEC_DESIGN", "회색 KROAD_SEC_AXIS / 흰색 KROAD_SEC_TEXT", "DATUM: 각 횡단 기준표고 · Y좌표=배치기준+표고−DATUM", "결측은 선을 끊고 단독 유효 표본은 POINT · 사면 폐합/수량 계산 없음", "", "STA(m) | DATUM(m) | 원지반/설계 결측 | 원지반/설계 도형 조각"])
 for section in result.sections:lines.append("%.3f | %.3f | %d / %d | %d / %d" % [section.station,section.datum,section.ground_missing,section.design_missing,section.ground_runs,section.design_runs])
 if result.grid_step>0:lines.insert(0,"격자 %.2fm · %d선 · GRID/GRID_TEXT 별도 레이어 · 눈금=실제 표고" % [result.grid_step,result.grid_lines])
 if result.extras_only:lines.insert(0,"추가 STA만 출력 · 구간 양 끝/정규 측점/주요 경계 자동 추가 없음")
 lines.insert(0,"출력선: 원지반 %s / 설계선 %s / 축선 %s" % [on_off(export_ground.button_pressed),on_off(export_design.button_pressed),on_off(export_axes.button_pressed)])
 lines.insert(1,"STA 표기: %s · 소수 %d자리 · 횡단 번호 %s" % ["km+m" if chainage_labels.button_pressed else "m",int(label_decimals.value),on_off(number_sections.button_pressed)])
 lines.insert(2,"글자 높이: %s · DATUM: %s" % ["자동" if text_height_input.value==0 else "%.2fm" % text_height_input.value,"공통 %.3fm" % common_datum_input.value if common_datum_enabled.button_pressed else "횡단별 자동"])
 lines.insert(3,"반폭 %.2fm · 횡단 간격 %.2fm · 배치 %d열 · 결측 통계는 원지반/설계 전체 기준" % [result.half,result.lateral_step,result.columns])
 lines.insert(0,missing_summary(result.sections,result.lateral_count))
 table.text="\n".join(lines)


func export_csv(path):
 if result.is_empty() or requested_inputs!=input_signature():
  invalidate()
  return false
 return super.export_csv(path)


func reset_settings():
 interval.value=1000
 reach.value=100
 lateral_step.value=2
 columns.value=3
 grid_enabled.button_pressed=false
 grid_interval.value=10
 grid_interval.editable=false
 include_boundaries.button_pressed=false
 chainage_labels.button_pressed=false
 label_decimals.value=3
 extras_only.button_pressed=false
 interval.editable=true
 include_boundaries.disabled=false
 extra_input.text=""
 text_height_input.value=0
 number_sections.button_pressed=false
 common_datum_enabled.button_pressed=false
 common_datum_input.value=0
 common_datum_input.editable=false
 export_ground.button_pressed=true
 export_design.button_pressed=true
 export_axes.button_pressed=true
 full_range()
 status.text="출력 설정을 기본값으로 초기화했습니다. 다시 산출하세요."


func on_off(enabled):
 return "켜짐" if enabled else "꺼짐"


func invalidate():
 super.invalidate()
 if copy_button!=null:copy_button.disabled=true
 if report_button!=null:report_button.disabled=true

func result_text():
 if result.is_empty() or worker!=null or requested_inputs!=input_signature() or result_revision!=revision_provider.call():
  invalidate()
  return ""
 return table.text

func copy_result():
 var content=result_text()
 if content.is_empty():return false
 DisplayServer.clipboard_set(content)
 status.text="산출 결과를 클립보드에 복사했습니다."
 return true


func save_report(path):
 var content=result_text()
 if content.is_empty():return false
 var temporary=path+".tmp"
 var file=FileAccess.open(temporary,FileAccess.WRITE)
 if file==null:
  status.text="결과 TXT 파일을 열지 못했습니다."
  return false
 file.store_string(content+"\n")
 file.flush()
 var error=file.get_error()
 file.close()
 if error!=OK or DirAccess.rename_absolute(temporary,path)!=OK:
  DirAccess.remove_absolute(temporary)
  status.text="결과 TXT 저장에 실패했습니다."
  return false
 status.text="결과 TXT 저장 완료: "+path
 return true


static func missing_summary(sections,lateral_count):
 var affected=0
 var ground=0
 var design=0
 var ground_empty=0
 var design_empty=0
 var stations=[]
 for section in sections:
  ground+=section.ground_missing
  design+=section.design_missing
  if section.ground_missing>=lateral_count:ground_empty+=1
  if section.design_missing>=lateral_count:design_empty+=1
  if section.ground_missing>0 or section.design_missing>0:
   affected+=1
   if stations.size()<10:stations.append("%.3f" % section.station)
 if affected==0:return "결측 검사: 모든 횡단의 원지반·설계 표본 유효"
 return "결측 경고: %d/%d횡단 · 원지반 %d / 설계 %d표본 · 전체 결측 횡단 원지반 %d / 설계 %d\n결측 STA(m): %s%s · DEM 범위·원본 결측·설계 유효 범위를 확인하세요." % [affected,sections.size(),ground,design,ground_empty,design_empty,", ".join(stations)," 외 %d개" % (affected-10) if affected>10 else ""]
