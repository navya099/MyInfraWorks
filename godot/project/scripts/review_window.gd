extends Window
const Review=preload("res://scripts/design_review.gd")
const TITLES={"R_MIN":"최소 반경","LS_MIN":"최소 완화길이","GRADE_MAX":"최대 종단구배","K_CREST_MIN":"볼록 K","K_SAG_MIN":"오목 K","H_KINK":"평면곡선 미설정","V_KINK":"종단곡선 미설정"}
signal finding_selected(finding)
var snapshot_provider: Callable
var revision_provider: Callable
var inputs={}
var result={}
var result_revision=-1
var status: Label
var summary: Label
var table: Tree
var csv_button: Button
var csv_dialog: FileDialog

func _ready():
 title="설계 검토 / 사용자 기준"
 min_size=Vector2i(1000,520)
 close_requested.connect(hide)
 var margin=MarginContainer.new()
 margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 for side in ["left","right","top","bottom"]:margin.add_theme_constant_override("margin_"+side,12)
 add_child(margin)
 var root=VBoxContainer.new()
 margin.add_child(root)
 var note=Label.new()
 note.text="초기값은 동작 확인용 예시입니다. 적용 기준을 직접 입력하세요. · 국내 설계기준 적합성 판정 아님"
 note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 root.add_child(note)
 var horizontal=HBoxContainer.new()
 root.add_child(horizontal)
 number(horizontal,"min_r","최소 R(m)",100000)
 number(horizontal,"min_ls","최소 Ls(m)",10000)
 number(horizontal,"max_grade","최대 |구배|(%)",100)
 var vertical=HBoxContainer.new()
 root.add_child(vertical)
 number(vertical,"min_k_crest","볼록 최소 K(m/%)",100000)
 number(vertical,"min_k_sag","오목 최소 K(m/%)",100000)
 var calculate=Button.new()
 calculate.text="검토"
 calculate.pressed.connect(run_review)
 vertical.add_child(calculate)
 csv_button=Button.new()
 csv_button.text="CSV 저장"
 csv_button.disabled=true
 csv_button.pressed.connect(func():csv_dialog.popup_centered_ratio(0.7))
 vertical.add_child(csv_button)
 var reset=Button.new()
 reset.text="예시값 복원"
 reset.pressed.connect(func():
  for key in inputs:inputs[key].value=Review.DEFAULT_LIMITS[key])
 vertical.add_child(reset)
 status=Label.new()
 status.text="각 기준의 0은 해당 비교 생략 · 무곡선 교점 경고는 항상 검사 · 행 선택: 측점과 PI/PVI 이동"
 status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 root.add_child(status)
 summary=Label.new()
 summary.text="노선을 작성한 뒤 검토하세요."
 summary.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 root.add_child(summary)
 table=Tree.new()
 table.columns=8
 table.hide_root=true
 table.column_titles_visible=true
 table.size_flags_vertical=Control.SIZE_EXPAND_FILL
 var titles=["구분","항목","위치","시작 STA(m)","끝 STA(m)","실제값","기준값","단위"]
 for i in range(titles.size()):table.set_column_title(i,titles[i])
 table.item_selected.connect(select_row)
 root.add_child(table)
 var footer=Label.new()
 footer.text="검토 범위: R · Ls · 종단구배 · K · 무곡선 교점. 시거·편경사·배수·DEM 적합성 등은 별도 검토가 필요합니다."
 footer.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 root.add_child(footer)
 csv_dialog=FileDialog.new()
 csv_dialog.access=FileDialog.ACCESS_FILESYSTEM
 csv_dialog.file_mode=FileDialog.FILE_MODE_SAVE_FILE
 csv_dialog.filters=PackedStringArray(["*.csv ; Design review CSV"])
 csv_dialog.file_selected.connect(export_csv)
 add_child(csv_dialog)

func number(parent,key,label_text,maximum):
 var label=Label.new()
 label.text=label_text
 parent.add_child(label)
 var input=SpinBox.new()
 input.min_value=0
 input.max_value=maximum
 input.step=0.01
 input.value=Review.DEFAULT_LIMITS[key]
 input.custom_minimum_size.x=110
 input.value_changed.connect(func(_value):invalidate())
 inputs[key]=input
 parent.add_child(input)

func limits():
 var values={}
 for key in inputs:values[key]=inputs[key].value
 return values

func invalidate():
 result={}
 result_revision=-1
 if csv_button!=null:csv_button.disabled=true
 if status!=null:status.text="설계 또는 검토 기준 변경 · 다시 검토하세요."
 if summary!=null:summary.text="설계·기준 변경 후 다시 검토하세요."
 if table!=null:table.clear()

func run_review():
 invalidate()
 var state=snapshot_provider.call()
 var completed=Review.calculate(state.design,limits())
 if not completed.ok:
  status.text="검토 실패: "+str(completed.get("error","unknown"))
  return false
 result=completed
 result_revision=state.revision
 csv_button.disabled=false
 summary.text="사용자 기준 비교 · 위반 %d건 / 무곡선 경고 %d건 · %d항목 검사\n노선 %.3fm · 실제 최대 |구배| %.3f%% · %.2fms" % [result.violations,result.warnings,result.checks,result.length,result.max_grade,result.ms]
 status.text="0: 해당 비교 생략 · K=Lv/|구배차(%)| · 행 선택으로 이동 · 자세한 사유는 행에 마우스를 올리세요."
 var root=table.create_item()
 if result.issues.is_empty():
  var item=table.create_item(root)
  item.set_text(1,"지적 없음")
  item.set_metadata(0,-1)
 for i in range(result.issues.size()):
  var row=result.issues[i]
  var item=table.create_item(root)
  var cells=["위반" if row.severity=="limit" else "경고",TITLES.get(row.code,row.code),row.kind+" "+str(row.index),"%.3f" % row.start,"%.3f" % row.end,"%.3f" % row.value,"—" if row.limit==null else "%.3f" % row.limit,row.unit]
  for column in range(cells.size()):
   item.set_text(column,cells[column])
   item.set_tooltip_text(column,row.detail)
  item.set_custom_color(0,Color("ffbd69") if row.severity=="limit" else Color("a8d4ef"))
  item.set_metadata(0,i)
 return true

func select_row():
 if result.is_empty() or result_revision!=revision_provider.call():return
 var item=table.get_selected()
 if item==null:return
 var index=int(item.get_metadata(0))
 if index>=0 and index<result.issues.size():finding_selected.emit(result.issues[index])

func export_csv(path):
 if result.is_empty() or result_revision!=revision_provider.call():
  invalidate()
  return false
 var temporary=path+".tmp_"+str(Time.get_ticks_usec())
 var file=FileAccess.open(temporary,FileAccess.WRITE)
 if file==null:
  status.text="CSV 파일을 열지 못했습니다."
  return false
 file.store_buffer(PackedByteArray([239,187,191]))
 file.store_csv_line(PackedStringArray(["record_type","min_radius_m","min_spiral_m","max_abs_grade_pct","min_k_crest_m_per_pct","min_k_sag_m_per_pct","alignment_length_m","max_actual_abs_grade_pct","checks","violations","warnings","severity","code","location_kind","location_index","start_station_m","end_station_m","navigation_station_m","actual_value","limit_value","unit","detail"]))
 var prefix=PackedStringArray(["summary",str(result.limits.min_r),str(result.limits.min_ls),str(result.limits.max_grade),str(result.limits.min_k_crest),str(result.limits.min_k_sag),str(result.length),str(result.max_grade),str(result.checks),str(result.violations),str(result.warnings)])
 var summary_row=prefix.duplicate()
 for i in range(11):summary_row.append("")
 summary_row[21]="사용자 입력 기준 비교 · 국내 설계기준 적합성 판정 아님"
 file.store_csv_line(summary_row)
 for row in result.issues:
  var values=prefix.duplicate()
  values[0]="finding"
  values.append_array(PackedStringArray([row.severity,row.code,row.kind,str(row.index),str(row.start),str(row.end),str(row.station),str(row.value),"" if row.limit==null else str(row.limit),row.unit,row.detail]))
  file.store_csv_line(values)
 file.flush()
 var error=file.get_error()
 file.close()
 if error!=OK or DirAccess.rename_absolute(temporary,path)!=OK:
  DirAccess.remove_absolute(temporary)
  status.text="CSV 저장 실패 · 기존 파일은 보존됩니다."
  return false
 status.text="CSV 저장 완료 · summary 행에 기준값과 집계가 포함됩니다."
 return true
