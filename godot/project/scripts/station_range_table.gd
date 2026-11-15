extends "res://scripts/station_table.gd"
const BaseTable=preload("res://scripts/station_table.gd")
var begin_input: LineEdit
var end_input: LineEdit
var range_length=-1.0
var requested_inputs=PackedStringArray()
const PAGE_SIZE=200
var page=0
var previous_button: Button
var next_button: Button
var page_label: Label
var find_input: LineEdit
var find_button: Button

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
 var paging=HBoxContainer.new()
 root.add_child(paging)
 root.move_child(paging,root.get_child_count()-2)
 previous_button=page_button(paging,"이전 페이지",func():page-=1;show_page())
 next_button=page_button(paging,"다음 페이지",func():page+=1;show_page())
 page_label=Label.new()
 paging.add_child(page_label)
 find_input=LineEdit.new()
 find_input.placeholder_text="찾을 STA(m)"
 find_input.custom_minimum_size.x=150
 find_input.max_length=32
 find_input.text_submitted.connect(func(_text):find_station())
 paging.add_child(find_input)
 find_button=page_button(paging,"STA 찾기",find_station)
 invalidate()
 hint.text="200행씩 표시 · STA 찾기: 가장 가까운 산출 측점으로 이동 · CSV 전체 저장 · 구간 양 끝·STA 0 기준 정규 측점·PI/PVI/곡선 경계 포함 · 행 선택: 원래 STA 이동 · CSV 전체 산출 행 저장"

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
 if find_button!=null:find_button.disabled=true
 if page_label!=null:page_label.text=""

func valid_result():
 if result.is_empty():return false
 if result_revision!=revision_provider.call() or requested_inputs!=input_signature():
  invalidate()
  return false
 return true

func render_rows():
 page=0
 show_page()

func show_page():
 if not valid_result():return
 page=clampi(page,0,(result.rows.size()-1)/PAGE_SIZE)
 var first=page*PAGE_SIZE
 var end=min(first+PAGE_SIZE,result.rows.size())
 previous_button.disabled=page==0
 next_button.disabled=end==result.rows.size()
 find_button.disabled=false
 page_label.text="%d~%d / %d행 · CSV는 전체 저장" % [first+1,end,result.rows.size()]
 render_slice(first,end)

static func nearest_index(rows,station):
 var low=0
 var high=rows.size()-1
 while low<high:
  var middle=(low+high)/2
  if rows[middle].station<station:low=middle+1
  else:high=middle
 if low>0 and station-rows[low-1].station<=rows[low].station-station:return low-1
 return low

func find_station():
 if not valid_result():return
 if not find_input.text.is_valid_float():
  status.text="찾을 STA를 숫자로 입력하세요."
  return
 var station=find_input.text.to_float()
 if not is_finite(station) or station<result.begin or station>result.end:
  status.text="산출 구간 안의 STA를 입력하세요."
  return
 var index=nearest_index(result.rows,station)
 page=index/PAGE_SIZE
 show_page()
 setting_table=true
 table.set_caret_line(index%PAGE_SIZE+1)
 table.center_viewport_to_caret()
 setting_table=false
 select_row()
 status.text="요청 STA %.3f → 산출 STA %.3fm · CSV는 전체 %d행 저장" % [station,result.rows[index].station,result.rows.size()]

func select_row():
 if setting_table or not valid_result():return
 var line=table.get_caret_line()
 var index=page*PAGE_SIZE+line-1
 if line>0 and index<result.rows.size():station_selected.emit(result.rows[index].station)

func export_csv(path):
 if result.is_empty() or requested_inputs!=input_signature():
  invalidate()
  return false
 return super.export_csv(path)
