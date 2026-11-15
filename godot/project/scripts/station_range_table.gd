extends "res://scripts/station_table.gd"
const BaseTable=preload("res://scripts/station_table.gd")
var begin_input: LineEdit
var end_input: LineEdit
var range_length=-1.0
var requested_inputs=PackedStringArray()

func _ready():
 super._ready()
 var row=HBoxContainer.new()
 var root=table.get_parent()
 root.add_child(row)
 root.move_child(row,1)
 for title_text in ["시작 STA(m)","끝 STA(m)"]:
  var label=Label.new()
  label.text=title_text
  row.add_child(label)
  var input=LineEdit.new()
  input.custom_minimum_size.x=150
  input.max_length=32
  input.text_changed.connect(func(_text):invalidate())
  row.add_child(input)
  if begin_input==null:begin_input=input
  else:end_input=input
 var full_button=Button.new()
 full_button.text="전체 범위"
 full_button.pressed.connect(full_range)
 row.add_child(full_button)
 hint.text="구간 양 끝·STA 0 기준 정규 측점·PI/PVI/곡선 경계 포함 · 행 선택: 원래 STA 이동 · CSV 전체 산출 행 저장"

func full_range():
 var state=snapshot_provider.call()
 begin_input.text="0"
 end_input.text=str(state.length)
 range_length=state.length
 invalidate()

func open_export():
 if range_length!=snapshot_provider.call().length:full_range()
 popup_centered(Vector2i(1250,650))

func input_signature():
 return PackedStringArray([begin_input.text,end_input.text,str(interval.value)])

func start_calculation():
 if worker!=null:
  status.text="이전 산출 종료 후 다시 산출하세요."
  return
 if range_length<0:full_range()
 var state=snapshot_provider.call()
 invalidate()
 if not begin_input.text.is_valid_float() or not end_input.text.is_valid_float():
  status.text="시작·끝 STA를 숫자로 입력하세요."
  return
 var bounds={"begin":begin_input.text.to_float(),"end":state.length if end_input.text==str(state.length) else end_input.text.to_float()}
 requested_inputs=input_signature()
 requested_revision=state.revision
 requested_generation=generation
 status.text="구간 측점표 산출 중 · 경계 포함 최대 20000행"
 worker=Thread.new()
 if worker.start(BaseTable.calculate_job.bind(state.snapshot,interval.value,bounds))!=OK:
  worker=null
  status.text="작업 스레드를 시작하지 못했습니다."

func _process(delta):
 if worker==null or worker.is_alive():return
 if requested_inputs!=input_signature():invalidate()
 super._process(delta)
 if not result.is_empty():status.text+=" · STA %.3f~%.3fm" % [result.begin,result.end]

func select_row():
 if not result.is_empty() and requested_inputs!=input_signature():
  invalidate()
  return
 super.select_row()

func export_csv(path):
 if result.is_empty() or requested_inputs!=input_signature():
  invalidate()
  return false
 return super.export_csv(path)
