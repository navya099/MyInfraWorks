extends "res://scripts/dxf_window.gd"
const CrossDxf=preload("res://scripts/section_dxf_geometry.gd")
var reach: SpinBox
var lateral_step: SpinBox
var columns: SpinBox
var begin_input: LineEdit
var end_input: LineEdit
var range_length=-1.0
var requested_inputs=PackedStringArray()

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
 csv_dialog.filters=PackedStringArray(["*.dxf ; Cross-section layout DXF"])
 hint.text="지정 구간 양 끝+STA 0 기준 정규 측점 · 도면 단위 m · H:V=1:1 · 원지반/설계 별도 레이어
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

func input_signature():
 return PackedStringArray([begin_input.text,end_input.text,str(interval.value),str(reach.value),str(lateral_step.value),str(columns.value)])

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
 if worker.start(CrossDxf.calculate_job.bind(state.snapshot,interval.value,reach.value,lateral_step.value,int(columns.value),bounds))!=OK:
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
 var lines=PackedStringArray(["출력 STA %.3f~%.3fm · 구간 길이 %.3fm · 원래 STA 유지" % [result.begin,result.end,result.end-result.begin],"DXF R12 ASCII / H:V 1:1 / Z=0 배치 / CAD 단위 m", "녹색 KROAD_SEC_GROUND / 노랑 KROAD_SEC_DESIGN", "회색 KROAD_SEC_AXIS / 흰색 KROAD_SEC_TEXT", "DATUM: 각 횡단 기준표고 · Y좌표=배치기준+표고−DATUM", "결측은 선을 끊고 단독 유효 표본은 POINT · 사면 폐합/수량 계산 없음", "", "STA(m) | DATUM(m) | 원지반/설계 결측 | 원지반/설계 도형 조각"])
 for section in result.sections:lines.append("%.3f | %.3f | %d / %d | %d / %d" % [section.station,section.datum,section.ground_missing,section.design_missing,section.ground_runs,section.design_runs])
 table.text="\n".join(lines)


func export_csv(path):
 if result.is_empty() or requested_inputs!=input_signature():
  invalidate()
  return false
 return super.export_csv(path)
