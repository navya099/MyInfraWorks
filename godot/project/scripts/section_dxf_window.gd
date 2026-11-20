extends "res://scripts/dxf_window.gd"
const CrossDxf=preload("res://scripts/section_dxf_geometry.gd")
var search_input: LineEdit
var review_range={}
var review_begin: LineEdit
var review_end: LineEdit
var navigation_buttons=[]
var row_stations={}
var collection_after_edit=null
var redo_collection_button: Button
var collection_before_edit=null
var undo_collection_button: Button
var collection_revision=-1
var collected_stations: Array[float]=[]
var collection_jump_button: Button
var copy_collection_button: Button
var collection_picker: OptionButton
var remove_collection_button: Button
var remove_displayed_button: Button
var uncollected_only: CheckBox
var collected_only: CheckBox
var collect_displayed_button: Button
var collection_button: Button
var apply_collection_button: Button
var recalculate_selected_button: Button
var recalculate_review_button: Button
var full_report_text=""
var report_include_summary: CheckBox
var details_only: CheckBox
var result_sort: OptionButton
var wrap_results: CheckBox
var default_result_font=14
var settings_rows=[]
var collapse_button: Button
var preset_export_dialog: FileDialog
var preset_import_dialog: FileDialog
var selected_summary: Label
var missing_type: OptionButton
var missing_only: CheckBox
var result_csv_button: Button
var result_csv_dialog: FileDialog
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
 table.gui_input.connect(func(event):
  if handle_result_input(event):table.accept_event())
 table.tooltip_text="Ctrl+휠: 글자 크기 · Ctrl+0: 기본 크기 · Alt+←/→: 이전/다음 횡단"
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
 result_csv_button=Button.new()
 result_csv_button.text="결과 CSV 저장"
 result_csv_button.disabled=true
 settings.add_child(result_csv_button)
 result_csv_dialog=FileDialog.new()
 result_csv_dialog.access=FileDialog.ACCESS_FILESYSTEM
 result_csv_dialog.file_mode=FileDialog.FILE_MODE_SAVE_FILE
 result_csv_dialog.filters=PackedStringArray(["*.csv ; Cross-section result table"])
 add_child(result_csv_dialog)
 result_csv_button.pressed.connect(func():result_csv_dialog.popup_centered_ratio(0.7))
 result_csv_dialog.file_selected.connect(save_result_csv)
 missing_only=CheckBox.new()
 missing_only.text="결측 횡단만 표시"
 missing_only.toggled.connect(func(_enabled):render_result())
 settings.add_child(missing_only)
 missing_type=OptionButton.new()
 for label in ["모든 결측","원지반 결측","설계 결측","전체 표본 결측","유효 50% 미만","유효 75% 미만","유효 90% 미만","유효 100% 미만"]:missing_type.add_item(label)
 missing_type.disabled=true
 missing_type.item_selected.connect(func(_index):render_result())
 missing_only.toggled.connect(func(enabled):missing_type.disabled=not enabled)
 settings.add_child(missing_type)
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
 var navigation_row=HBoxContainer.new()
 root.add_child(navigation_row)
 root.move_child(navigation_row,6)
 for direction in [-1,1]:
  var button=Button.new()
  button.text="이전 횡단" if direction<0 else "다음 횡단"
  button.disabled=true
  button.pressed.connect(move_result.bind(direction))
  navigation_row.add_child(button)
  navigation_buttons.append(button)
 search_input=LineEdit.new()
 search_input.placeholder_text="검색 STA(m)"
 search_input.custom_minimum_size.x=180
 search_input.max_length=32
 navigation_row.add_child(search_input)
 var find_button=Button.new()
 find_button.text="가까운 횡단 찾기"
 find_button.disabled=true
 find_button.pressed.connect(find_result)
 search_input.text_submitted.connect(func(_text):find_result())
 navigation_row.add_child(find_button)
 navigation_buttons.append(find_button)
 var current_result=Button.new()
 current_result.text="현재 STA 결과 찾기"
 current_result.disabled=true
 current_result.pressed.connect(find_current_result)
 navigation_row.add_child(current_result)
 navigation_buttons.append(current_result)
 var worst_row=HBoxContainer.new()
 root.add_child(worst_row)
 for ground in [true,false]:
  var button=Button.new()
  button.text="원지반 유효 최저로 이동" if ground else "설계 유효 최저로 이동"
  button.disabled=true
  button.pressed.connect(find_worst_result.bind(ground))
  worst_row.add_child(button)
  navigation_buttons.append(button)
 var preset_row=HBoxContainer.new()
 root.add_child(preset_row)
 root.move_child(preset_row,7)
 for action in ["설정 저장","설정 불러오기"]:
  var button=Button.new()
  button.text=action
  if action=="설정 저장":button.pressed.connect(func():save_preset())
  else:button.pressed.connect(func():load_preset())
  preset_row.add_child(button)
 for exporting in [true,false]:
  var dialog=FileDialog.new()
  dialog.access=FileDialog.ACCESS_FILESYSTEM
  dialog.file_mode=FileDialog.FILE_MODE_SAVE_FILE if exporting else FileDialog.FILE_MODE_OPEN_FILE
  dialog.filters=PackedStringArray(["*.cfg ; Cross-section export settings"])
  dialog.title="출력 설정 파일 내보내기" if exporting else "출력 설정 파일 가져오기"
  add_child(dialog)
  if exporting:
   preset_export_dialog=dialog
   dialog.file_selected.connect(save_preset)
  else:
   preset_import_dialog=dialog
   dialog.file_selected.connect(load_preset)
  var button=Button.new()
  button.text="설정 파일 내보내기" if exporting else "설정 파일 가져오기"
  button.pressed.connect(dialog.popup_centered_ratio.bind(0.7))
  preset_row.add_child(button)
 selected_summary=Label.new()
 selected_summary.text="선택 횡단: 없음"
 selected_summary.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 root.add_child(selected_summary)
 root.move_child(selected_summary,8)
 settings_rows=[extra,range_row,extra_row,style_row,datum_row,preset_row]
 collapse_button=Button.new()
 collapse_button.text="설정 접기"
 collapse_button.toggle_mode=true
 collapse_button.toggled.connect(set_settings_collapsed)
 var view_row=HBoxContainer.new()
 root.add_child(view_row)
 root.move_child(view_row,9)
 view_row.add_child(collapse_button)
 default_result_font=table.get_theme_font_size("font_size")
 for action in ["결과 글자 −","결과 글자 +","글자 기본값"]:
  var button=Button.new()
  button.text=action
  if action=="글자 기본값":button.pressed.connect(func():set_result_font(default_result_font))
  elif action=="결과 글자 +":button.pressed.connect(func():set_result_font(table.get_theme_font_size("font_size")+2))
  else:button.pressed.connect(func():set_result_font(table.get_theme_font_size("font_size")-2))
  view_row.add_child(button)
 wrap_results=CheckBox.new()
 wrap_results.text="결과 자동 줄바꿈"
 wrap_results.toggled.connect(func(enabled):
  table.wrap_mode=TextEdit.LINE_WRAPPING_BOUNDARY if enabled else TextEdit.LINE_WRAPPING_NONE)
 view_row.add_child(wrap_results)
 details_only=CheckBox.new()
 details_only.text="상세 목록만 표시"
 details_only.toggled.connect(func(_enabled):render_result())
 view_row.add_child(details_only)
 result_sort=OptionButton.new()
 for label in ["STA 순","원지반 유효 낮은 순","설계 유효 낮은 순"]:result_sort.add_item(label)
 result_sort.item_selected.connect(func(_index):render_result())
 view_row.add_child(result_sort)
 root.move_child(worst_row,table.get_index())
 var export_row=HBoxContainer.new()
 root.add_child(export_row)
 root.move_child(export_row,1)
 for control in [csv_button,copy_button,report_button,result_csv_button]:control.reparent(export_row)
 report_include_summary=CheckBox.new()
 report_include_summary.text="TXT 전체 요약 포함"
 report_include_summary.button_pressed=true
 export_row.add_child(report_include_summary)
 recalculate_review_button=Button.new()
 recalculate_review_button.text="표시 STA로 재산출"
 recalculate_review_button.disabled=true
 recalculate_review_button.pressed.connect(recalculate_review)
 export_row.add_child(recalculate_review_button)
 recalculate_selected_button=Button.new()
 recalculate_selected_button.text="선택 횡단 재산출"
 recalculate_selected_button.disabled=true
 recalculate_selected_button.pressed.connect(recalculate_selected)
 export_row.add_child(recalculate_selected_button)
 collection_button=Button.new()
 collection_button.text="선택 STA 담기"
 collection_button.disabled=true
 collection_button.pressed.connect(collect_selected_station)
 worst_row.add_child(collection_button)
 collect_displayed_button=Button.new()
 collect_displayed_button.text="표시 STA 모두 담기"
 collect_displayed_button.disabled=true
 collect_displayed_button.pressed.connect(collect_displayed_stations)
 worst_row.add_child(collect_displayed_button)
 remove_displayed_button=Button.new()
 remove_displayed_button.text="표시 STA 모두 빼기"
 remove_displayed_button.disabled=true
 remove_displayed_button.pressed.connect(remove_displayed_stations)
 worst_row.add_child(remove_displayed_button)
 apply_collection_button=Button.new()
 apply_collection_button.disabled=true
 apply_collection_button.pressed.connect(calculate_collection)
 worst_row.add_child(apply_collection_button)
 var clear_collection=Button.new()
 clear_collection.text="담은 STA 비우기"
 clear_collection.pressed.connect(func():
  if collected_stations.is_empty():return
  remember_collection()
  collected_stations.clear()
  refresh_collection_view())
 worst_row.add_child(clear_collection)
 collection_picker=OptionButton.new()
 collection_picker.tooltip_text="담은 STA 목록 (m)"
 worst_row.add_child(collection_picker)
 collection_jump_button=Button.new()
 collection_jump_button.text="담은 STA로 이동"
 collection_jump_button.pressed.connect(jump_to_collected_station)
 worst_row.add_child(collection_jump_button)
 remove_collection_button=Button.new()
 remove_collection_button.text="담은 STA 제거"
 remove_collection_button.pressed.connect(remove_collected_station)
 worst_row.add_child(remove_collection_button)
 copy_collection_button=Button.new()
 copy_collection_button.text="담은 STA 복사"
 copy_collection_button.pressed.connect(copy_collected_stations)
 worst_row.add_child(copy_collection_button)
 var paste_button=Button.new()
 paste_button.text="STA 붙여넣기"
 paste_button.pressed.connect(func():paste_collected_stations(DisplayServer.clipboard_get()))
 worst_row.add_child(paste_button)
 undo_collection_button=Button.new()
 undo_collection_button.text="STA 편집 되돌리기"
 undo_collection_button.pressed.connect(undo_collection_edit)
 worst_row.add_child(undo_collection_button)
 redo_collection_button=Button.new()
 redo_collection_button.text="STA 편집 다시 실행"
 redo_collection_button.pressed.connect(redo_collection_edit)
 worst_row.add_child(redo_collection_button)
 update_collection_button()
 var filter_row=HBoxContainer.new()
 root.add_child(filter_row)
 root.move_child(filter_row,view_row.get_index()+1)
 for control in [missing_only,missing_type,result_sort]:control.reparent(filter_row)
 review_begin=LineEdit.new()
 review_end=LineEdit.new()
 for input in [review_begin,review_end]:
  input.custom_minimum_size.x=110
  input.max_length=32
  filter_row.add_child(input)
 review_begin.placeholder_text="표시 시작 STA"
 review_end.placeholder_text="표시 끝 STA"
 var apply_range=Button.new()
 apply_range.text="목록 범위 적용"
 apply_range.pressed.connect(apply_review_range)
 filter_row.add_child(apply_range)
 var reset_filter=Button.new()
 reset_filter.text="목록 필터 초기화"
 reset_filter.pressed.connect(reset_review_filters)
 filter_row.add_child(reset_filter)
 collected_only=CheckBox.new()
 collected_only.text="담은 STA만 표시"
 filter_row.add_child(collected_only)
 uncollected_only=CheckBox.new()
 uncollected_only.text="안 담은 STA만 표시"
 filter_row.add_child(uncollected_only)
 collected_only.toggled.connect(func(enabled):
  if enabled:uncollected_only.set_pressed_no_signal(false)
  render_result())
 uncollected_only.toggled.connect(func(enabled):
  if enabled:collected_only.set_pressed_no_signal(false)
  render_result())
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
 result_csv_button.disabled=false
 status.text="%d횡단 / %d표본 · 원지반 결측 %d · %.1fms" % [result.sections.size(),result.samples,result.missing,result.ms]
 render_result()

func render_result():
 if result.is_empty():return
 var selected_station=row_stations.get(table.get_caret_line(),null)
 if requested_inputs!=input_signature() or result_revision!=revision_provider.call():
  invalidate()
  return
 var lines=PackedStringArray(["주요 경계 %s · 경계 포함 횡단 %d개" % ["포함" if result.include_boundaries else "제외",result.boundary_sections],"추가 STA 입력 %d개 · 중복 병합 후 총 %d횡단" % [result.extra_requested,result.sections.size()],"출력 STA %.3f~%.3fm · 구간 길이 %.3fm · 원래 STA 유지" % [result.begin,result.end,result.end-result.begin],"DXF R12 ASCII / H:V 1:1 / Z=0 배치 / CAD 단위 m", "녹색 KROAD_SEC_GROUND / 노랑 KROAD_SEC_DESIGN", "회색 KROAD_SEC_AXIS / 흰색 KROAD_SEC_TEXT", "DATUM: 각 횡단 기준표고 · Y좌표=배치기준+표고−DATUM", "결측은 선을 끊고 단독 유효 표본은 POINT · 사면 폐합/수량 계산 없음", "", "STA(m) | DATUM(m) | 원지반/설계 결측 | 원지반/설계 도형 조각 | 원지반/설계 유효(%)"])
 var visible=displayed_sections()
 for section in visible:lines.append("%.3f | %.3f | %d / %d | %d / %d | %.1f / %.1f" % [section.station,section.datum,section.ground_missing,section.design_missing,section.ground_runs,section.design_runs,valid_percent(section.ground_missing,result.lateral_count),valid_percent(section.design_missing,result.lateral_count)])
 if result.grid_step>0:lines.insert(0,"격자 %.2fm · %d선 · GRID/GRID_TEXT 별도 레이어 · 눈금=실제 표고" % [result.grid_step,result.grid_lines])
 if result.extras_only:lines.insert(0,"추가 STA만 출력 · 구간 양 끝/정규 측점/주요 경계 자동 추가 없음")
 lines.insert(0,"출력선: 원지반 %s / 설계선 %s / 축선 %s" % [on_off(export_ground.button_pressed),on_off(export_design.button_pressed),on_off(export_axes.button_pressed)])
 lines.insert(1,"STA 표기: %s · 소수 %d자리 · 횡단 번호 %s" % ["km+m" if chainage_labels.button_pressed else "m",int(label_decimals.value),on_off(number_sections.button_pressed)])
 lines.insert(2,"글자 높이: %s · DATUM: %s" % ["자동" if text_height_input.value==0 else "%.2fm" % text_height_input.value,"공통 %.3fm" % common_datum_input.value if common_datum_enabled.button_pressed else "횡단별 자동"])
 lines.insert(3,"반폭 %.2fm · 횡단 간격 %.2fm · 배치 %d열 · 결측 통계는 원지반/설계 전체 기준" % [result.half,result.lateral_step,result.columns])
 lines.insert(0,missing_summary(result.sections,result.lateral_count))
 lines.insert(0,coverage_summary(result.sections,result.lateral_count))
 lines.insert(0,coverage_summary(visible,result.lateral_count,"표시"))
 lines.insert(0,missing_ranges_summary(result.sections))
 if not review_range.is_empty():lines.insert(0,"목록 STA 범위 %.3f~%.3fm · DXF 출력 범위와 별도" % [review_range.begin,review_range.end])
 lines.insert(0,"정렬: "+result_sort.get_item_text(result_sort.selected))
 lines.insert(0,"목록: %s · 표시 %d / 전체 %d횡단 · DXF는 전체 횡단 출력" % ["결측만 / "+missing_type.get_item_text(missing_type.selected) if missing_only.button_pressed else "전체",visible.size(),result.sections.size()])
 full_report_text="\n".join(lines)
 if details_only.button_pressed:
  var header=lines.find("STA(m) | DATUM(m) | 원지반/설계 결측 | 원지반/설계 도형 조각 | 원지반/설계 유효(%)")
  lines=lines.slice(header)
 if collected_only.button_pressed:lines.insert(0,"목록 필터: 담은 STA만 표시")
 if uncollected_only.button_pressed:lines.insert(0,"목록 필터: 안 담은 STA만 표시")
 selected_summary.text="선택 횡단: 없음"
 setting_table=true
 row_stations.clear()
 var first_row="\n".join(lines).split("\n").find("STA(m) | DATUM(m) | 원지반/설계 결측 | 원지반/설계 도형 조각 | 원지반/설계 유효(%)")+1
 for i in range(visible.size()):row_stations[first_row+i]=visible[i].station
 table.text="\n".join(lines)
 var restored=false
 if selected_station!=null:
  for row in row_stations:
   if row_stations[row]==selected_station:
    table.set_caret_line(row)
    table.center_viewport_to_caret()
    restored=true
    break
 if not restored:table.set_caret_line(0)
 setting_table=false
 recalculate_selected_button.disabled=not restored
 collection_button.disabled=not restored
 collect_displayed_button.disabled=visible.is_empty()
 update_collection_button()
 if restored:select_row(false)
 recalculate_review_button.disabled=visible.is_empty() or visible.size()>100
 for button in navigation_buttons:button.disabled=row_stations.is_empty()


func export_csv(path):
 if result.is_empty() or requested_inputs!=input_signature():
  invalidate()
  return false
 return super.export_csv(path)


func reset_settings():
 collection_after_edit=null
 collection_before_edit=null
 collected_only.set_pressed_no_signal(false)
 uncollected_only.set_pressed_no_signal(false)
 collected_stations.clear()
 update_collection_button()
 review_range={}
 review_begin.text=""
 review_end.text=""
 result_sort.select(0)
 missing_type.select(0)
 missing_type.disabled=true
 search_input.text=""
 missing_only.button_pressed=false
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
 if collect_displayed_button!=null:collect_displayed_button.disabled=true
 if collection_button!=null:collection_button.disabled=true
 if apply_collection_button!=null:apply_collection_button.disabled=true
 if recalculate_selected_button!=null:recalculate_selected_button.disabled=true
 if recalculate_review_button!=null:recalculate_review_button.disabled=true
 full_report_text=""
 if selected_summary!=null:selected_summary.text="선택 횡단: 없음"
 for button in navigation_buttons:button.disabled=true
 row_stations.clear()
 super.invalidate()
 if collection_picker!=null:update_collection_button()
 if copy_button!=null:copy_button.disabled=true
 if report_button!=null:report_button.disabled=true
 if result_csv_button!=null:result_csv_button.disabled=true

func result_text(include_summary=false):
 if result.is_empty() or worker!=null or requested_inputs!=input_signature() or result_revision!=revision_provider.call():
  invalidate()
  return ""
 return full_report_text if include_summary else table.text

func copy_result():
 var content=result_text()
 if content.is_empty():return false
 DisplayServer.clipboard_set(content)
 status.text="산출 결과를 클립보드에 복사했습니다."
 return true


func save_report(path):
 var content=result_text(report_include_summary.button_pressed)
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


func select_row(navigate=true):
 if setting_table or result.is_empty():return
 if requested_inputs!=input_signature() or result_revision!=revision_provider.call():
  invalidate()
  return
 var row=table.get_caret_line()
 recalculate_selected_button.disabled=not row_stations.has(row)
 collection_button.disabled=recalculate_selected_button.disabled
 if row_stations.has(row):
  var station=row_stations[row]
  for section in result.sections:
   if section.station==station:
    selected_summary.text="선택 STA %.3fm · DATUM %.3fm · 원지반 결측 %d/%d · 설계 결측 %d/%d · 도형 조각 %d/%d" % [station,section.datum,section.ground_missing,result.lateral_count,section.design_missing,result.lateral_count,section.ground_runs,section.design_runs]
    selected_summary.text+=" · 유효 원지반 %.1f%% / 설계 %.1f%%" % [valid_percent(section.ground_missing,result.lateral_count),valid_percent(section.design_missing,result.lateral_count)]
    break
  if navigate:station_selected.emit(station)
 else:selected_summary.text="선택 횡단: 없음"


func move_result(direction):
 if result_text().is_empty() or row_stations.is_empty():return false
 var rows=row_stations.keys()
 rows.sort()
 var index=rows.find(table.get_caret_line())
 if index<0:index=0 if direction>0 else rows.size()-1
 else:index=posmod(index+direction,rows.size())
 setting_table=true
 table.set_caret_line(rows[index])
 table.center_viewport_to_caret()
 setting_table=false
 select_row()
 return true


func find_result():
 if result_text().is_empty() or row_stations.is_empty():return false
 var token=search_input.text.strip_edges()
 if not token.is_valid_float() or not is_finite(token.to_float()) or token.to_float()<0:
  status.text="검색 STA는 0 이상의 유한한 미터 값으로 입력하세요."
  return false
 var target=token.to_float()
 var rows=row_stations.keys()
 rows.sort()
 var best=rows[0]
 for row in rows:
  if abs(row_stations[row]-target)<abs(row_stations[best]-target) or (abs(row_stations[row]-target)==abs(row_stations[best]-target) and row_stations[row]<row_stations[best]):best=row
 setting_table=true
 table.set_caret_line(best)
 table.center_viewport_to_caret()
 setting_table=false
 select_row()
 status.text="검색 %.3fm → 표시 목록의 가장 가까운 STA %.3fm" % [target,row_stations[best]]
 return true


func find_current_result():
 if result_text().is_empty() or row_stations.is_empty():return false
 var station=snapshot_provider.call().station
 if not is_finite(station) or station<0:return false
 search_input.text=str(station)
 return find_result()


static func matches_missing(section,lateral_count,mode):
 if mode>=4 and mode<=7:
  var threshold=[50.0,75.0,90.0,100.0][mode-4]
  return min(valid_percent(section.ground_missing,lateral_count),valid_percent(section.design_missing,lateral_count))<threshold
 match mode:
  1:return section.ground_missing>0
  2:return section.design_missing>0
  3:return section.ground_missing>=lateral_count or section.design_missing>=lateral_count
 return section.ground_missing>0 or section.design_missing>0


func preset_controls():
 return {"interval":interval,"reach":reach,"lateral_step":lateral_step,"columns":columns,"grid_interval":grid_interval,"label_decimals":label_decimals,"text_height":text_height_input,"datum":common_datum_input,"grid":grid_enabled,"boundaries":include_boundaries,"chainage":chainage_labels,"number":number_sections,"common_datum":common_datum_enabled,"ground":export_ground,"design":export_design,"axes":export_axes}

func save_preset(path="user://section-export.cfg"):
 var config=ConfigFile.new()
 config.set_value("format","version",1)
 var controls=preset_controls()
 for key in controls:
  var control=controls[key]
  config.set_value("settings",key,control.value if control is SpinBox else control.button_pressed)
 config.set_value("view","font_size",table.get_theme_font_size("font_size"))
 config.set_value("view","wrap",wrap_results.button_pressed)
 config.set_value("view","collapsed",collapse_button.button_pressed)
 var temporary=path+".tmp"
 if config.save(temporary)!=OK or DirAccess.rename_absolute(temporary,path)!=OK:
  DirAccess.remove_absolute(temporary)
  status.text="출력 설정 저장 실패"
  return false
 status.text="출력 설정 저장 완료"
 return true

func load_preset(path="user://section-export.cfg"):
 var config=ConfigFile.new()
 if config.load(path)!=OK:
  status.text="저장된 출력 설정을 읽지 못했습니다."
  return false
 var version=config.get_value("format","version",null)
 if typeof(version)!=TYPE_INT or version!=1:
  status.text="저장된 출력 설정을 읽지 못했습니다."
  return false
 var controls=preset_controls()
 for key in controls:
  var value=config.get_value("settings",key,null)
  var control=controls[key]
  if control is SpinBox:
   if not (typeof(value) in [TYPE_INT,TYPE_FLOAT]) or not is_finite(value) or value<control.min_value or value>control.max_value:
    status.text="출력 설정 값 오류: "+key
    return false
   if control.step>0 and abs(value/control.step-round(value/control.step))>0.000001:
    status.text="출력 설정 입력 간격 오류: %s (간격 %s)" % [key,str(control.step)]
    return false
  elif typeof(value)!=TYPE_BOOL:
   status.text="출력 설정 값 오류: "+key
   return false
 if not config.get_value("settings","ground") and not config.get_value("settings","design"):
  status.text="원지반·설계선 중 하나 이상 선택해야 합니다."
  return false
 var font_size=config.get_value("view","font_size",table.get_theme_font_size("font_size"))
 var wrap=config.get_value("view","wrap",wrap_results.button_pressed)
 var collapsed=config.get_value("view","collapsed",collapse_button.button_pressed)
 if typeof(font_size)!=TYPE_INT or font_size<10 or font_size>30 or typeof(wrap)!=TYPE_BOOL or typeof(collapsed)!=TYPE_BOOL:
  status.text="결과 화면 보기 설정 값 오류"
  return false
 for key in controls:
  var control=controls[key]
  var value=config.get_value("settings",key)
  if control is SpinBox:control.value=value
  else:control.button_pressed=value
 grid_interval.editable=grid_enabled.button_pressed
 common_datum_input.editable=common_datum_enabled.button_pressed
 invalidate()
 set_result_font(font_size)
 wrap_results.button_pressed=wrap
 collapse_button.button_pressed=collapsed
 status.text="출력 설정을 불러왔습니다. 범위·추가 STA 확인 후 다시 산출하세요."
 return true


func set_settings_collapsed(collapsed):
 for row in settings_rows:row.visible=not collapsed
 collapse_button.text="설정 펼치기" if collapsed else "설정 접기"


func set_result_font(size):
 table.add_theme_font_size_override("font_size",clampi(size,10,30))


func handle_result_input(event):
 if event is InputEventMouseButton and event.pressed and event.ctrl_pressed and not event.alt_pressed and not event.shift_pressed:
  if event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
   set_result_font(table.get_theme_font_size("font_size")+(2 if event.button_index==MOUSE_BUTTON_WHEEL_UP else -2))
   return true
 if event is InputEventKey and event.pressed and not event.echo:
  if event.ctrl_pressed and not event.alt_pressed and not event.shift_pressed and event.keycode==KEY_0:
   set_result_font(default_result_font)
   return true
  if event.alt_pressed and not event.ctrl_pressed and not event.shift_pressed and event.keycode in [KEY_LEFT,KEY_RIGHT]:
   move_result(-1 if event.keycode==KEY_LEFT else 1)
   return true
 return false


func save_result_csv(path):
 if result_text().is_empty():return false
 var temporary=path+".tmp"
 var file=FileAccess.open(temporary,FileAccess.WRITE)
 if file==null:
  status.text="결과 CSV 파일을 열지 못했습니다."
  return false
 file.store_buffer(PackedByteArray([239,187,191]))
 file.store_csv_line(PackedStringArray(["station_m","datum_m","samples_per_section","ground_missing","design_missing","ground_runs","design_runs","list_filter","ground_valid_pct","design_valid_pct"]))
 var filter_name=missing_type.get_item_text(missing_type.selected) if missing_only.button_pressed else "전체"
 if collected_only.button_pressed:filter_name+=" / 담은 STA만"
 if uncollected_only.button_pressed:filter_name+=" / 안 담은 STA만"
 if not review_range.is_empty():filter_name+="; STA %.9f~%.9f" % [review_range.begin,review_range.end]
 for section in displayed_sections():
  file.store_csv_line(PackedStringArray([str(section.station),str(section.datum),str(result.lateral_count),str(section.ground_missing),str(section.design_missing),str(section.ground_runs),str(section.design_runs),filter_name,str(valid_percent(section.ground_missing,result.lateral_count)),str(valid_percent(section.design_missing,result.lateral_count))]))
 file.flush()
 var error=file.get_error()
 file.close()
 if error!=OK or DirAccess.rename_absolute(temporary,path)!=OK:
  DirAccess.remove_absolute(temporary)
  status.text="결과 CSV 저장 실패"
  return false
 status.text="결과 CSV 저장 완료: "+path
 return true


static func valid_percent(missing,total):
 return 0.0 if total<=0 else 100.0*(total-missing)/total


func displayed_sections():
 var visible=result.sections.filter(func(section):return not missing_only.button_pressed or matches_missing(section,result.lateral_count,missing_type.selected))
 if not review_range.is_empty():visible=visible.filter(func(section):return section.station>=review_range.begin and section.station<=review_range.end)
 if collected_only.button_pressed:
  visible=visible.filter(func(section):return collected_stations.has(section.station))
 if uncollected_only.button_pressed:
  visible=visible.filter(func(section):return not collected_stations.has(section.station))
 return sorted_sections(visible,result_sort.selected)

static func sorted_sections(sections,mode):
 var ordered=sections.duplicate()
 ordered.sort_custom(func(a,b):
  if mode>0:
   var key="ground_missing" if mode==1 else "design_missing"
   if a[key]!=b[key]:return a[key]>b[key]
  return a.station<b.station)
 return ordered


static func coverage_summary(sections,total,scope="전체"):
 if sections.is_empty():return scope+" 유효 비율: 산출 횡단 없음"
 var ground_sum=0.0
 var design_sum=0.0
 var ground_min=100.0
 var design_min=100.0
 for section in sections:
  var ground=valid_percent(section.ground_missing,total)
  var design=valid_percent(section.design_missing,total)
  ground_sum+=ground
  design_sum+=design
  ground_min=min(ground_min,ground)
  design_min=min(design_min,design)
 return "%s %d횡단 유효 표본 비율 · 원지반 평균 %.1f%% / 최저 %.1f%% · 설계 평균 %.1f%% / 최저 %.1f%% (%s 기준)" % [scope,sections.size(),ground_sum/sections.size(),ground_min,design_sum/sections.size(),design_min,"필터 전 전체" if scope=="전체" else "현재 필터 목록"]


func find_worst_result(ground):
 if result_text().is_empty() or row_stations.is_empty():return false
 var ordered=sorted_sections(displayed_sections(),1 if ground else 2)
 var worst=ordered[0]
 for row in row_stations:
  if row_stations[row]==worst.station:
   setting_table=true
   table.set_caret_line(row)
   table.center_viewport_to_caret()
   setting_table=false
   select_row()
   status.text="표시 목록 기준 %s 유효 최저 STA %.3fm · %.1f%%" % ["원지반" if ground else "설계",worst.station,valid_percent(worst.ground_missing if ground else worst.design_missing,result.lateral_count)]
   return true
 return false


static func missing_ranges(sections):
 var ordered=sections.duplicate()
 ordered.sort_custom(func(a,b):return a.station<b.station)
 var ranges=[]
 var active={}
 for section in ordered:
  if section.ground_missing>0 or section.design_missing>0:
   if active.is_empty():active={"begin":section.station,"end":section.station,"count":0}
   active.end=section.station
   active.count+=1
  elif not active.is_empty():
   ranges.append(active)
   active={}
 if not active.is_empty():ranges.append(active)
 return ranges

static func missing_ranges_summary(sections):
 var ranges=missing_ranges(sections)
 if ranges.is_empty():return "연속 결측 측점 묶음: 없음"
 var labels=[]
 for i in range(mini(5,ranges.size())):
  var group=ranges[i]
  labels.append("%.3f~%.3fm (%d횡단)" % [group.begin,group.end,group.count])
 return "연속 결측 측점 묶음 %d개: %s%s · STA 순 인접 산출 횡단 기준, 측점 사이 지형은 미검사" % [ranges.size(),", ".join(labels)," 외 %d개" % (ranges.size()-5) if ranges.size()>5 else ""]


func apply_review_range():
 var begin=review_begin.text.strip_edges()
 var finish=review_end.text.strip_edges()
 if begin.is_empty() and finish.is_empty():
  review_range={}
 elif not begin.is_valid_float() or not finish.is_valid_float() or not is_finite(begin.to_float()) or not is_finite(finish.to_float()) or begin.to_float()<0 or finish.to_float()<begin.to_float():
  status.text="목록 범위는 0 이상 시작≤끝 STA로 입력하세요. 빈 두 칸은 전체입니다."
  return false
 else:review_range={"begin":begin.to_float(),"end":finish.to_float()}
 render_result()
 return true


func reset_review_filters():
 collected_only.set_pressed_no_signal(false)
 uncollected_only.set_pressed_no_signal(false)
 missing_only.set_pressed_no_signal(false)
 missing_type.select(0)
 missing_type.disabled=true
 result_sort.select(0)
 review_range={}
 review_begin.text=""
 review_end.text=""
 render_result()
 if not result.is_empty():status.text="목록 필터를 초기화했습니다. 전체 결과를 STA 순으로 표시합니다."


func recalculate_review():
 if result_text().is_empty():return false
 var sections=sorted_sections(displayed_sections(),0)
 if sections.is_empty() or sections.size()>100:return false
 return recalculate_stations(sections.map(func(section):return section.station))

func recalculate_selected():
 if result_text().is_empty():return false
 var row=table.get_caret_line()
 if not row_stations.has(row):return false
 return recalculate_stations([row_stations[row]])

static func format_station_list(station_values):
 var stations=PackedStringArray()
 for station in station_values:
  stations.append(JSON.stringify(station,"",true,true))
 return ", ".join(stations)

func recalculate_stations(station_values):
 var station_list=format_station_list(station_values)
 if station_list.length()>extra_input.max_length:
  status.text="STA 목록이 입력 가능한 길이를 넘었습니다."
  return false
 extra_input.text=station_list
 extras_only.button_pressed=true
 start_calculation()
 return worker!=null


func update_collection_button():
 if collection_revision!=revision_provider.call():
  collected_stations.clear()
  collection_before_edit=null
  collection_after_edit=null
 redo_collection_button.disabled=collection_after_edit==null
 undo_collection_button.disabled=collection_before_edit==null
 apply_collection_button.text="담은 STA 재산출 (%d)" % collected_stations.size()
 apply_collection_button.disabled=collected_stations.is_empty() or result.is_empty()
 var selected_index=collection_picker.selected
 collection_picker.clear()
 var empty=collected_stations.is_empty()
 if empty:
  collection_picker.add_item("담은 STA 없음")
 else:
  for station in collected_stations:
   collection_picker.add_item(JSON.stringify(station,"",true,true)+" m")
 collection_picker.select(clampi(selected_index,0,collection_picker.item_count-1))
 var has_visible_match=false
 if not empty and not result.is_empty():
  for station in row_stations.values():
   if collected_stations.has(station):
    has_visible_match=true
    break
 remove_displayed_button.disabled=not has_visible_match
 copy_collection_button.disabled=empty
 collection_picker.disabled=empty
 remove_collection_button.disabled=empty
 collection_jump_button.disabled=empty

func remove_collected_station():
 var index=collection_picker.selected
 if index<0 or index>=collected_stations.size():return
 remember_collection()
 collected_stations.remove_at(index)
 refresh_collection_view()


func collect_selected_station():
 if result_text().is_empty():return false
 var row=table.get_caret_line()
 if not row_stations.has(row):return false
 var station=row_stations[row]
 if collected_stations.has(station):
  status.text="이미 담은 STA입니다."
  return false
 if collected_stations.size()>=100:
  status.text="STA는 최대 100개까지 담을 수 있습니다."
  return false
 collection_revision=result_revision
 remember_collection()
 collected_stations.append(station)
 refresh_collection_view()
 status.text="STA %.3fm을 담았습니다." % station
 return true

func calculate_collection():
 if result_text().is_empty() or collected_stations.is_empty():return false
 for station in collected_stations:
  if station<result.begin or station>result.end:
   status.text="출력 구간 밖에 담은 STA가 있습니다. 구간을 확인하거나 목록을 비우세요."
   return false
 return recalculate_stations(collected_stations)


func jump_to_collected_station():
 if collection_revision!=revision_provider.call():
  update_collection_button()
  return false
 var index=collection_picker.selected
 if index<0 or index>=collected_stations.size():return false
 var station=collected_stations[index]
 station_selected.emit(station)
 status.text="담은 STA %.3fm으로 이동했습니다." % station
 return true


func collect_displayed_stations():
 if result_text().is_empty():return false
 var additions: Array[float]=[]
 for section in displayed_sections():
  if not collected_stations.has(section.station):
   additions.append(section.station)
 if additions.is_empty():
  status.text="새로 담을 표시 STA가 없습니다."
  return false
 if collected_stations.size()+additions.size()>100:
  status.text="담은 STA가 100개를 넘습니다. 필터 범위를 좁혀 주세요."
  return false
 collection_revision=result_revision
 remember_collection()
 collected_stations.append_array(additions)
 refresh_collection_view()
 status.text="표시 STA %d개를 담았습니다." % additions.size()
 return true


func remove_displayed_stations():
 if result_text().is_empty():return false
 var visible_stations={}
 for section in displayed_sections():
  visible_stations[section.station]=true
 var previous_count=collected_stations.size()
 var remaining=collected_stations.filter(func(station):return not visible_stations.has(station))
 var removed=previous_count-remaining.size()
 if removed==0:return false
 remember_collection()
 collected_stations.assign(remaining)
 refresh_collection_view()
 status.text="담은 목록에서 표시 STA %d개를 뺐습니다." % removed
 return true


func refresh_collection_view():
 if (collected_only.button_pressed or uncollected_only.button_pressed) and not result.is_empty():
  render_result()
 else:
  update_collection_button()


func copy_collected_stations():
 update_collection_button()
 if collected_stations.is_empty():return false
 DisplayServer.clipboard_set(format_station_list(collected_stations))
 status.text="담은 STA %d개를 복사했습니다." % collected_stations.size()
 return true


func paste_collected_stations(content):
 if result_text().is_empty():
  status.text="횡단을 산출한 뒤 STA를 붙여넣으세요."
  return false
 var parsed=CrossDxf.parse_extra(content)
 if not parsed.ok:
  status.text=parsed.error
  return false
 var additions: Array[float]=[]
 for station in parsed.stations:
  if station<result.begin or station>result.end:
   status.text="출력 구간 밖 STA가 있습니다."
   return false
  if not collected_stations.has(station) and not additions.has(station):
   additions.append(station)
 if additions.is_empty():
  status.text="새로 담을 STA가 없습니다."
  return false
 if collected_stations.size()+additions.size()>100:
  status.text="담은 STA는 최대 100개입니다."
  return false
 collection_revision=result_revision
 remember_collection()
 collected_stations.append_array(additions)
 refresh_collection_view()
 status.text="STA %d개를 붙여넣었습니다." % additions.size()
 return true


func remember_collection():
 collection_after_edit=null
 collection_before_edit=collected_stations.duplicate()

func undo_collection_edit():
 if collection_revision!=revision_provider.call() or collection_before_edit==null:
  update_collection_button()
  return false
 collection_after_edit=collected_stations.duplicate()
 collected_stations.assign(collection_before_edit)
 collection_before_edit=null
 refresh_collection_view()
 status.text="마지막 STA 목록 편집을 되돌렸습니다."
 return true


func redo_collection_edit():
 if collection_revision!=revision_provider.call() or collection_after_edit==null:
  update_collection_button()
  return false
 collection_before_edit=collected_stations.duplicate()
 collected_stations.assign(collection_after_edit)
 collection_after_edit=null
 refresh_collection_view()
 status.text="되돌린 STA 목록 편집을 다시 실행했습니다."
 return true
