extends "res://scripts/station_table.gd"
signal profile_export_requested
signal section_export_requested
const Geometry=preload("res://scripts/dxf_geometry.gd")
var coordinate_mode: OptionButton
var annotation_enabled: CheckBox
var annotation_interval: SpinBox
var annotation_height: SpinBox
var plan_begin: LineEdit
var plan_end: LineEdit
var plan_range_length=-1.0
var plan_requested_inputs=PackedStringArray()

func _ready():
 super._ready()
 title="CAD DXF 내보내기"
 interval.min_value=1
 interval.max_value=25
 interval.step=1
 interval.value=10
 settings.get_child(0).text="최대 측점 간격(m)"
 csv_button.text="DXF 저장"
 csv_dialog.filters=PackedStringArray(["*.dxf ; CAD 3D polyline DXF"])
 coordinate_mode=OptionButton.new()
 coordinate_mode.add_item("로컬 동/북 좌표")
 coordinate_mode.add_item("DEM 좌표 EPSG:5179")
 coordinate_mode.item_selected.connect(func(_index):invalidate())
 settings.add_child(coordinate_mode)
 if get_script()==load("res://scripts/dxf_window.gd"):
  var section_button=Button.new()
  section_button.text="횡단 DXF..."
  section_button.pressed.connect(func():section_export_requested.emit())
  settings.add_child(section_button)
  var profile_button=Button.new()
  profile_button.text="종단 DXF..."
  profile_button.pressed.connect(func():profile_export_requested.emit())
  settings.add_child(profile_button)
  var annotation_row=HBoxContainer.new()
  var root=table.get_parent()
  root.add_child(annotation_row)
  root.move_child(annotation_row,1)
  annotation_enabled=CheckBox.new()
  annotation_enabled.text="STA 주석 추가"
  annotation_row.add_child(annotation_enabled)
  var label=Label.new()
  label.text="주석 간격(m)"
  annotation_row.add_child(label)
  annotation_interval=SpinBox.new()
  annotation_interval.min_value=10
  annotation_interval.max_value=10000
  annotation_interval.step=10
  annotation_interval.value=1000
  annotation_interval.editable=false
  annotation_interval.value_changed.connect(func(_value):invalidate())
  annotation_row.add_child(annotation_interval)
  var height_label=Label.new()
  height_label.text="문자 높이(m)"
  annotation_row.add_child(height_label)
  annotation_height=SpinBox.new()
  annotation_height.min_value=0
  annotation_height.max_value=100
  annotation_height.step=0.1
  annotation_height.editable=false
  annotation_height.value_changed.connect(func(_value):invalidate())
  annotation_row.add_child(annotation_height)
  annotation_enabled.toggled.connect(func(enabled):annotation_interval.editable=enabled;annotation_height.editable=enabled;invalidate())
  var note=Label.new()
  note.text="높이 0=폭 기준 자동 · 시점/종점 포함"
  annotation_row.add_child(note)
  var range_row=HBoxContainer.new()
  root.add_child(range_row)
  root.move_child(range_row,2)
  for text in ["시작 STA(m)","끝 STA(m)"]:
   var range_label=Label.new()
   range_label.text=text
   range_row.add_child(range_label)
   var input=LineEdit.new()
   input.custom_minimum_size.x=150
   input.max_length=32
   input.text_changed.connect(func(_text):invalidate())
   range_row.add_child(input)
   if plan_begin==null:plan_begin=input
   else:plan_end=input
  var full_button=Button.new()
  full_button.text="전체 범위"
  full_button.pressed.connect(plan_full_range)
  range_row.add_child(full_button)
  var range_note=Label.new()
  range_note.text="원래 STA·지도 좌표 유지 · 구간 양 끝 포함"
  range_row.add_child(range_note)
 hint.text="중심선·좌/우 가장자리 3D 폴리라인 · 1 도면 단위=1m(CAD 가져오기 단위 m) · 곡선은 선분 근사"
 status.text="좌표와 간격을 지정하고 산출하세요."

func plan_full_range():
 var state=snapshot_provider.call()
 plan_begin.text="0"
 plan_end.text=str(state.length)
 plan_range_length=state.length
 invalidate()

func plan_input_signature():
 if plan_begin==null:return PackedStringArray()
 return PackedStringArray([plan_begin.text,plan_end.text,str(interval.value),str(coordinate_mode.selected),str(annotation_enabled.button_pressed),str(annotation_interval.value),str(annotation_height.value)])

func open_export():
 var state=snapshot_provider.call()
 if plan_begin!=null and plan_range_length!=state.length:plan_full_range()
 coordinate_mode.set_item_disabled(1,not Geometry.has_origin(state.snapshot.source))
 if coordinate_mode.is_item_disabled(1) and coordinate_mode.selected==1:
  coordinate_mode.select(0)
  invalidate()
 popup_centered(Vector2i(1150,600))

func start_calculation():
 if worker!=null:
  status.text="이전 산출 종료를 기다려 주세요."
  return
 var state=snapshot_provider.call()
 invalidate()
 var bounds={}
 if plan_begin!=null:
  if not plan_begin.text.is_valid_float() or not plan_end.text.is_valid_float():
   status.text="시작·끝 STA를 숫자로 입력하세요."
   return
  bounds={"begin":plan_begin.text.to_float(),"end":state.length if plan_end.text==str(state.length) else plan_end.text.to_float()}
 plan_requested_inputs=plan_input_signature()
 requested_revision=state.revision
 requested_generation=generation
 status.text="DXF 산출 중"
 worker=Thread.new()
 var annotation_step=annotation_interval.value if annotation_enabled!=null and annotation_enabled.button_pressed else 0.0
 var height=annotation_height.value if annotation_enabled!=null and annotation_enabled.button_pressed else 0.0
 if worker.start(Geometry.calculate_job.bind(state.snapshot,interval.value,coordinate_mode.selected,annotation_step,height,bounds))!=OK:
  worker=null
  status.text="작업 스레드를 시작하지 못했습니다."

func _process(_delta):
 if worker==null or worker.is_alive():return
 var completed=worker.wait_to_finish()
 worker=null
 if requested_revision!=revision_provider.call() or requested_generation!=generation or plan_requested_inputs!=plan_input_signature():
  status.text="변경 전 산출 결과를 버렸습니다. 다시 산출하세요."
  return
 if not completed.ok:
  status.text="산출 실패: "+str(completed.get("error","unknown"))
  return
 result=completed
 result_revision=requested_revision
 csv_button.disabled=false
 status.text="%d개 노선 정점 / %d개 측점 / 주석 %d개 · %s · %.1fms" % [result.vertices,result.stations,result.annotation_count,"로컬 동/북" if result.crs=="LOCAL_EAST_NORTH" else result.crs,result.ms]
 table.text="DXF R12 ASCII / 3D POLYLINE\nKROAD_CENTER: 중심선\nKROAD_LEFT: 진행 방향 좌측 도로 가장자리\nKROAD_RIGHT: 진행 방향 우측 도로 가장자리\n\n전체 노선 %.3fm / 최대 측점 간격 %.1fm\n단위 m · X 동쪽 / Y 북쪽 / Z 설계 표고\n3D 화면의 표시용 높이 보정은 제외합니다.\n지형·사면·Civil 3D 선형 객체는 포함하지 않습니다." % [result.length,result.spacing]

 table.text+="\n출력 STA %.3f~%.3fm · 구간 길이 %.3fm · 좌표 원점 이동 없음" % [result.begin,result.end,result.end-result.begin]
 if result.annotation_count>0:table.text+="\n\nKROAD_STA_TICK: 측점 표식 / KROAD_STA_TEXT: STA 문자\n주석 간격 %.1fm · 회전 -90~90도 · 문자/표식 Z는 중심 계획고\n중첩 문자 자동 회피는 하지 않습니다. 간격이나 CAD 문자 위치를 조정하세요." % result.annotation_step

func select_row():
 pass

func export_csv(path):
 if result.is_empty() or result_revision!=revision_provider.call() or plan_requested_inputs!=plan_input_signature():
  invalidate()
  return false
 var temporary=path+".tmp_"+str(Time.get_ticks_usec())
 var file=FileAccess.open(temporary,FileAccess.WRITE)
 if file==null:
  status.text="DXF 파일을 열지 못했습니다."
  return false
 file.store_string(result.text)
 file.flush()
 var error=file.get_error()
 file.close()
 if error!=OK or DirAccess.rename_absolute(temporary,path)!=OK:
  DirAccess.remove_absolute(temporary)
  status.text="DXF 저장 실패 · 기존 파일은 보존됩니다."
  return false
 status.text="DXF 저장 완료 · CAD에서 가져오기 단위를 m로 지정하세요."
 return true
