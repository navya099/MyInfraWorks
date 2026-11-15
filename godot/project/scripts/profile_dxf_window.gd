extends "res://scripts/dxf_window.gd"
const ProfileDxf=preload("res://scripts/profile_dxf_geometry.gd")
var begin_input: LineEdit
var end_input: LineEdit
var factor: SpinBox
var requested_inputs=PackedStringArray()
var range_length=-1.0

func _ready():
 super._ready()
 title="종단 DXF 내보내기"
 coordinate_mode.hide()
 interval.max_value=10000
 interval.value=20
 settings.get_child(0).text="측점 간격(m)"
 var extra=HBoxContainer.new()
 var root=table.get_parent()
 root.add_child(extra)
 root.move_child(extra,1)
 for title_text in ["시작 STA(m)","끝 STA(m)"]:
  var label=Label.new()
  label.text=title_text
  extra.add_child(label)
  var input=LineEdit.new()
  input.custom_minimum_size.x=150
  input.max_length=32
  input.text_changed.connect(func(_text):invalidate())
  extra.add_child(input)
  if begin_input==null:begin_input=input
  else:end_input=input
 var all_button=Button.new()
 all_button.text="전체 범위"
 all_button.pressed.connect(full_range)
 extra.add_child(all_button)
 var label=Label.new()
 label.text="세로 확대(배)"
 extra.add_child(label)
 factor=SpinBox.new()
 factor.min_value=1
 factor.max_value=100
 factor.step=0.1
 factor.value=10
 factor.value_changed.connect(func(_value):invalidate())
 extra.add_child(factor)
 hint.text="X=STA−시작 · Y=(표고−DATUM)×세로 배율 · Z=0 · 도면 X 단위 m
원지반 결측은 선 끊기 / 계획선 유지 · CAD 가져오기 단위 m · 지도/EPSG 좌표 아님"
 csv_dialog.filters=PackedStringArray(["*.dxf ; Longitudinal profile DXF"])

func full_range():
 var state=snapshot_provider.call()
 begin_input.text="0"
 end_input.text=str(state.length)
 range_length=state.length
 invalidate()

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
 var begin=begin_input.text.to_float()
 var finish=state.length if end_input.text==str(state.length) else end_input.text.to_float()
 requested_inputs=input_signature()
 requested_revision=state.revision
 requested_generation=generation
 status.text="종단 DXF 산출 중 · 경계 포함 최대 20000표본"
 worker=Thread.new()
 if worker.start(ProfileDxf.calculate_job.bind(state.snapshot,interval.value,begin,finish,factor.value))!=OK:
  worker=null
  status.text="작업 스레드를 시작하지 못했습니다."

func _process(_delta):
 if worker==null or worker.is_alive():return
 var completed=worker.wait_to_finish()
 worker=null
 if requested_revision!=revision_provider.call() or requested_generation!=generation or requested_inputs!=input_signature():
  status.text="설계/DEM/조건 변경 전 종단 도면을 버렸습니다. 다시 산출하세요."
  return
 if not completed.ok:
  status.text="종단 DXF 실패: "+str(completed.get("error","unknown"))
  return
 result=completed
 result_revision=requested_revision
 csv_button.disabled=false
 status.text="STA %.3f~%.3fm / %d표본 · 원지반 결측 %d · %.2fms" % [result.begin,result.end,result.stations.size(),result.missing,result.ms]
 table.text="DXF R12 ASCII / Z=0 종단 배치
KROAD_PROF_GROUND: 원지반 / KROAD_PROF_DESIGN: 실제 계획고
KROAD_PROF_AXIS: 축 / KROAD_PROF_TEXT: 문자

DATUM %.3fm · 세로 확대 %.2f배 · 표고 범위 %.3f~%.3fm
원지반 선 조각 %d · 구간 양 끝/PVI/종단곡선 경계/정점/평면 경계 포함
X=STA−시작, 실제 표고=Y/세로배율+DATUM
표본 사이 선분 근사 · PVI 제어점 연결선/수량 계산 아님" % [result.datum,result.factor,result.low,result.high,result.ground_runs]


func input_signature():
 return PackedStringArray([begin_input.text,end_input.text,str(interval.value),str(factor.value)])

func export_csv(path):
 if result.is_empty() or requested_inputs!=input_signature():
  invalidate()
  return false
 return super.export_csv(path)
