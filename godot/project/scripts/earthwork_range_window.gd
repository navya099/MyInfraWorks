extends Window
signal station_selected(station)
const RangeCalculation=preload("res://scripts/earthwork_range.gd")
const COLUMNS=["method","boundary_method","station_step_m","half_width_m","lateral_step_m","range_start_m","range_end_m","range_status","range_coverage_ratio","interval_start_m","interval_end_m","source_start_m","source_end_m","interval_status","cut_start_area_m2","cut_end_area_m2","fill_start_area_m2","fill_end_area_m2","cut_volume_m3","fill_volume_m3","detail"]
const PAGE_SIZE=200
var page=0
var page_label: Label
var previous_button: Button
var next_button: Button
var result_inputs=PackedStringArray()
var revision_provider: Callable
var result_revision=-1
var report={}
var result={}
var begin_input: LineEdit
var end_input: LineEdit
var summary: Label
var status: Label
var settings_label: Label
var table: Tree
var csv_button: Button
var csv_dialog: FileDialog
var updating=false

func _ready():
 title="측점 범위별 토공량"
 min_size=Vector2i(1050,560)
 close_requested.connect(hide)
 var margin=MarginContainer.new()
 margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 for side in ["left","right","top","bottom"]:margin.add_theme_constant_override("margin_"+side,12)
 add_child(margin)
 var root=VBoxContainer.new()
 margin.add_child(root)
 var toolbar=HBoxContainer.new()
 root.add_child(toolbar)
 for label_text in ["시작 STA(m)","끝 STA(m)"]:
  var label=Label.new()
  label.text=label_text
  toolbar.add_child(label)
  var input=LineEdit.new()
  input.custom_minimum_size.x=160
  input.max_length=32
  input.text_changed.connect(func(_text):clear_result())
  input.text_submitted.connect(func(_text):calculate_range())
  toolbar.add_child(input)
  if begin_input==null:begin_input=input
  else:end_input=input
 add_button(toolbar,"범위 집계",calculate_range)
 add_button(toolbar,"전체 구간",full_range)
 csv_button=add_button(toolbar,"CSV 저장",func():csv_dialog.popup_centered_ratio(0.7))
 settings_label=Label.new()
 root.add_child(settings_label)
 status=Label.new()
 status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 root.add_child(status)
 summary=Label.new()
 summary.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 root.add_child(summary)
 for text in ["조사 측점 사이 경계: 단면적 선형 보간 · DEM 재조사 없음 · 범위를 좁혀도 조사 정밀도는 증가하지 않습니다.","제외 구간은 수량 미산출 · 행 선택: 표시 구간 중간 측점 이동 · 토량변화율/배분/비용 보정 없음"]:
  var note=Label.new()
  note.text=text
  root.add_child(note)
 var paging=HBoxContainer.new()
 root.add_child(paging)
 previous_button=add_button(paging,"이전 페이지",func():page-=1;render_page())
 next_button=add_button(paging,"다음 페이지",func():page+=1;render_page())
 page_label=Label.new()
 paging.add_child(page_label)
 table=Tree.new()
 table.columns=8
 table.hide_root=true
 table.column_titles_visible=true
 table.size_flags_vertical=Control.SIZE_EXPAND_FILL
 var titles=["시작(m)","끝(m)","길이(m)","상태","절토(m³)","성토(m³)","원본 구간(m)","제외 사유"]
 for i in range(titles.size()):
  table.set_column_title(i,titles[i])
  table.set_column_custom_minimum_width(i,100 if i<6 else 140)
 table.item_selected.connect(select_row)
 root.add_child(table)
 csv_dialog=FileDialog.new()
 csv_dialog.access=FileDialog.ACCESS_FILESYSTEM
 csv_dialog.file_mode=FileDialog.FILE_MODE_SAVE_FILE
 csv_dialog.filters=PackedStringArray(["*.csv ; Station range earthwork CSV"])
 csv_dialog.file_selected.connect(export_csv)
 add_child(csv_dialog)
 invalidate()

func add_button(parent,text,action):
 var button=Button.new()
 button.text=text
 button.pressed.connect(action)
 parent.add_child(button)
 return button

func clear_result():
 if updating:return
 result={}
 result_inputs=PackedStringArray()
 page=0
 if page_label!=null:page_label.text=""
 if previous_button!=null:previous_button.disabled=true
 if next_button!=null:next_button.disabled=true
 if table!=null:table.clear()
 if csv_button!=null:csv_button.disabled=true
 if summary!=null:summary.text=""
 if status!=null:status.text="범위 변경 · 다시 집계하세요."

func invalidate():
 report={}
 result_revision=-1
 clear_result()
 if settings_label!=null:settings_label.text=""
 if status!=null:status.text="토공량 창에서 현재 설계의 수량을 다시 계산하세요."

func show_report(value,revision):
 if not value.get("ok",false) or revision!=revision_provider.call():
  invalidate()
  return false
 report=value
 result_revision=revision
 settings_label.text="원본 조사: 측점 %.1fm / 반폭 %.1fm / 횡단 %.1fm · 원본 범위 %.6f~%.6fm" % [report.station_step,report.half_width,report.lateral_step,report.sections[0].station,report.sections[-1].station]
 full_range()
 popup_centered(Vector2i(1250,650))
 return true

func full_range():
 if report.is_empty():return
 updating=true
 begin_input.text=str(report.sections[0].station)
 end_input.text=str(report.sections[-1].station)
 updating=false
 calculate_range()

func calculate_range():
 if report.is_empty() or result_revision!=revision_provider.call():
  invalidate()
  return false
 clear_result()
 if not begin_input.text.is_valid_float() or not end_input.text.is_valid_float():
  status.text="시작·끝 측점을 숫자로 입력하세요."
  return false
 var begin=report.sections[0].station if begin_input.text==str(report.sections[0].station) else begin_input.text.to_float()
 var finish=report.sections[-1].station if end_input.text==str(report.sections[-1].station) else end_input.text.to_float()
 var calculated=RangeCalculation.calculate(report,begin,finish)
 if not calculated.ok:
  status.text=calculated.error
  return false
 result=calculated
 result_inputs=PackedStringArray([begin_input.text,end_input.text])
 csv_button.disabled=false
 var labels={"complete":"범위 전 구간","partial":"유효 구간 부분합","missing":"미산출"}
 summary.text="%s · 절토 %s m³ / 성토 %s m³ / 절토−성토 %s m³ · 유효 %.3f/%.3fm (%.2f%%)" % [labels[result.status],number_text(result.cut),number_text(result.fill),number_text(result.net),result.covered,result.length,result.coverage*100]
 status.text="STA %.6f~%.6fm · 포함 %d / 제외 %d구간 · %.2fms" % [result.start,result.end,result.included,result.excluded,result.ms]
 render_page()
 return true

func render_page():
 if result.is_empty():return
 page=clampi(page,0,(result.rows.size()-1)/PAGE_SIZE)
 var first=page*PAGE_SIZE
 var last=min(first+PAGE_SIZE,result.rows.size())
 previous_button.disabled=page==0
 next_button.disabled=last==result.rows.size()
 page_label.text="%d~%d / %d행 · CSV는 전체 범위 저장" % [first+1,last,result.rows.size()]
 updating=true
 table.clear()
 var root=table.create_item()
 for index in range(first,last):
  var row=result.rows[index]
  var item=table.create_item(root)
  item.set_metadata(0,(row.start+row.end)/2.0)
  var cells=["%.3f" % row.start,"%.3f" % row.end,"%.3f" % row.length,"유효" if row.status=="included" else "제외",number_text(row.cut),number_text(row.fill),"%.3f~%.3f" % [row.source_start,row.source_end],row.detail]
  for i in range(cells.size()):item.set_text(i,cells[i])
 updating=false

static func number_text(value):
 return "NA" if value==null else "%.3f" % value

func select_row():
 if updating or result.is_empty():return
 var item=table.get_selected()
 if item!=null:station_selected.emit(item.get_metadata(0))

func export_csv(path):
 if result.is_empty() or report.is_empty() or result_revision!=revision_provider.call():
  if result_revision!=revision_provider.call():invalidate()
  return false
 if result_inputs!=PackedStringArray([begin_input.text,end_input.text]):
  clear_result()
  return false
 var temporary=path+".tmp_"+str(Time.get_ticks_usec())
 var file=FileAccess.open(temporary,FileAccess.WRITE)
 if file==null:
  status.text="CSV 파일을 열지 못했습니다."
  return false
 file.store_buffer(PackedByteArray([239,187,191]))
 file.store_csv_line(PackedStringArray(COLUMNS))
 for row in result.rows:
  var values=["average_end_area","linear_section_area",report.station_step,report.half_width,report.lateral_step,result.start,result.end,result.status,result.coverage,row.start,row.end,row.source_start,row.source_end,row.status,row.cut_start,row.cut_end,row.fill_start,row.fill_end,row.cut,row.fill,row.detail]
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
 status.text="범위 토공량 CSV 저장 완료 · 제외 수량은 빈 셀입니다."
 return true
