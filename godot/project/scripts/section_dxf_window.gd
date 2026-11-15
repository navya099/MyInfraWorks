extends "res://scripts/dxf_window.gd"
const CrossDxf=preload("res://scripts/section_dxf_geometry.gd")
var reach: SpinBox
var lateral_step: SpinBox
var columns: SpinBox
var begin_input: LineEdit
var end_input: LineEdit
var range_length=-1.0
var requested_inputs=PackedStringArray()
var extra_input: LineEdit

func _ready():
 super._ready()
 title="횡단 DXF 일괄 내보내기"
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
 var extra_row=HBoxContainer.new()
 root.add_child(extra_row)
 root.move_child(extra_row,3)
 var extra_label=Label.new()
 extra_label.text="추가 STA(m)"
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
 csv_dialog.filters=PackedStringArray(["*.dxf ; Cross-section layout DXF"])
 hint.text="지정 구간 양 끝+정규 측점+추가 STA · 도면 단위 m · H:V=1:1 · 원지반/설계 별도 레이어
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
 return PackedStringArray([begin_input.text,end_input.text,str(interval.value),str(reach.value),str(lateral_step.value),str(columns.value),extra_input.text])

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
 if worker.start(CrossDxf.calculate_job.bind(state.snapshot,interval.value,reach.value,lateral_step.value,int(columns.value),bounds,extra_input.text))!=OK:
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
 status.text="%d횡단 / %d표본 · 원지반 결측 %d · %.1fms" % [result.sections.size(),result.samples,result.missing,result.ms]
 var lines=PackedStringArray(["추가 STA 입력 %d개 · 중복 병합 후 총 %d횡단" % [result.extra_requested,result.sections.size()],"출력 STA %.3f~%.3fm · 구간 길이 %.3fm · 원래 STA 유지" % [result.begin,result.end,result.end-result.begin],"DXF R12 ASCII / H:V 1:1 / Z=0 배치 / CAD 단위 m", "녹색 KROAD_SEC_GROUND / 노랑 KROAD_SEC_DESIGN", "회색 KROAD_SEC_AXIS / 흰색 KROAD_SEC_TEXT", "DATUM: 각 횡단 기준표고 · Y좌표=배치기준+표고−DATUM", "결측은 선을 끊고 단독 유효 표본은 POINT · 사면 폐합/수량 계산 없음", "", "STA(m) | DATUM(m) | 원지반/설계 결측 | 원지반/설계 도형 조각"])
 for section in result.sections:lines.append("%.3f | %.3f | %d / %d | %d / %d" % [section.station,section.datum,section.ground_missing,section.design_missing,section.ground_runs,section.design_runs])
 table.text="\n".join(lines)


func export_csv(path):
 if result.is_empty() or requested_inputs!=input_signature():
  invalidate()
  return false
 return super.export_csv(path)
