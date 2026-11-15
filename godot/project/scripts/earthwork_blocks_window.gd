extends "res://scripts/earthwork_range_window.gd"
signal range_selected(begin,finish)
const Blocks=preload("res://scripts/earthwork_blocks.gd")
const BLOCK_COLUMNS=["method","boundary_method","station_step_m","half_width_m","lateral_step_m","requested_start_m","requested_end_m","block_length_m","block_index","start_m","end_m","length_m","status","cut_m3","fill_m3","cut_minus_fill_m3","covered_length_m","coverage_ratio","included_source_intervals","excluded_source_intervals"]
var block_input: LineEdit
var result_block_text=""

func _ready():
 super._ready()
 title="일정 길이 구간별 토공량"
 var toolbar=begin_input.get_parent()
 var label=Label.new()
 label.text="분할 길이(m)"
 toolbar.add_child(label)
 block_input=LineEdit.new()
 block_input.custom_minimum_size.x=100
 block_input.max_length=32
 block_input.text="1000"
 block_input.text_changed.connect(func(_text):clear_result())
 block_input.text_submitted.connect(func(_text):calculate_range())
 toolbar.add_child(block_input)
 toolbar.move_child(label,4)
 toolbar.move_child(block_input,5)
 table.item_activated.connect(open_detail)
 table.columns=10
 var titles=["구간","시작(m)","끝(m)","상태","절토(m³)","성토(m³)","절토−성토","유효 길이(m)","비율(%)","제외 건수"]
 for i in range(titles.size()):
  table.set_column_title(i,titles[i])
  table.set_column_custom_minimum_width(i,70 if i in [0,8,9] else 100)
 var note=Label.new()
 note.text="입력 시작부터 분할 · 마지막 잔여 길이 포함 · 최대 1,000구간 · 행 더블클릭: 해당 범위 상세"
 var root=table.get_parent()
 root.add_child(note)
 root.move_child(note,root.get_child_count()-2)

func calculate_range():
 if report.is_empty() or result_revision!=revision_provider.call():
  invalidate()
  return false
 clear_result()
 if not begin_input.text.is_valid_float() or not end_input.text.is_valid_float() or not block_input.text.is_valid_float():
  status.text="시작·끝 측점과 분할 길이를 숫자로 입력하세요."
  return false
 var begin=report.sections[0].station if begin_input.text==str(report.sections[0].station) else begin_input.text.to_float()
 var finish=report.sections[-1].station if end_input.text==str(report.sections[-1].station) else end_input.text.to_float()
 var calculated=Blocks.calculate(report,begin,finish,block_input.text.to_float())
 if not calculated.ok:
  status.text=calculated.error
  return false
 result=calculated
 result_inputs=PackedStringArray([begin_input.text,end_input.text])
 result_block_text=block_input.text
 csv_button.disabled=false
 var labels={"complete":"전 범위 합계","partial":"유효 구간 부분합","missing":"미산출"}
 summary.text="%s · 절토 %s / 성토 %s / 절토−성토 %s m³ · 유효 %.3f/%.3fm (%.2f%%)" % [labels[result.status],number_text(result.cut),number_text(result.fill),number_text(result.net),result.covered,result.length,result.coverage*100]
 status.text="%d구간 · 완료 %d / 부분합 %d / 미산출 %d · %.2fms · 각 구간 제외 건수는 경계 분할로 중복될 수 있습니다." % [result.rows.size(),result.counts.complete,result.counts.partial,result.counts.missing,result.ms]
 render_page()
 return true

func render_page():
 if result.is_empty():return
 page=clampi(page,0,(result.rows.size()-1)/PAGE_SIZE)
 var first=page*PAGE_SIZE
 var last=min(first+PAGE_SIZE,result.rows.size())
 previous_button.disabled=page==0
 next_button.disabled=last==result.rows.size()
 page_label.text="%d~%d / %d구간 · CSV는 전체 범위 저장" % [first+1,last,result.rows.size()]
 updating=true
 table.clear()
 var root=table.create_item()
 var labels={"complete":"전 구간","partial":"부분합","missing":"미산출"}
 for i in range(first,last):
  var row=result.rows[i]
  var item=table.create_item(root)
  item.set_metadata(0,(row.start+row.end)/2.0)
  var cells=[str(row.index),"%.3f" % row.start,"%.3f" % row.end,labels[row.status],number_text(row.cut),number_text(row.fill),number_text(row.net),"%.3f" % row.covered,"%.2f" % (row.coverage*100),str(row.excluded)]
  for column in range(cells.size()):item.set_text(column,cells[column])
 updating=false

func open_detail():
 if result.is_empty():return
 var item=table.get_selected()
 if item!=null:
  var index=int(item.get_text(0))-1
  range_selected.emit(result.rows[index].start,result.rows[index].end)

func export_csv(path):
 if result.is_empty() or report.is_empty() or result_revision!=revision_provider.call():
  if result_revision!=revision_provider.call():invalidate()
  return false
 if result_inputs!=PackedStringArray([begin_input.text,end_input.text]) or result_block_text!=block_input.text:
  clear_result()
  return false
 var temporary=path+".tmp_"+str(Time.get_ticks_usec())
 var file=FileAccess.open(temporary,FileAccess.WRITE)
 if file==null:
  status.text="CSV 파일을 열지 못했습니다."
  return false
 file.store_buffer(PackedByteArray([239,187,191]))
 file.store_csv_line(PackedStringArray(BLOCK_COLUMNS))
 for row in result.rows:
  var cells=PackedStringArray()
  for value in ["average_end_area","linear_section_area",report.station_step,report.half_width,report.lateral_step,result.start,result.end,result.block_length,row.index,row.start,row.end,row.length,row.status,row.cut,row.fill,row.net,row.covered,row.coverage,row.included,row.excluded]:cells.append("" if value==null else str(value))
  file.store_csv_line(cells)
 file.flush()
 var error=file.get_error()
 file.close()
 if error!=OK or DirAccess.rename_absolute(temporary,path)!=OK:
  DirAccess.remove_absolute(temporary)
  status.text="CSV 저장 실패 · 기존 파일은 보존됩니다."
  return false
 status.text="분할 구간 CSV 저장 완료 · 미산출 수량은 빈 셀입니다."
 return true
