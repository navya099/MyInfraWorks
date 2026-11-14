extends Window
signal station_selected(station)
const Diagram=preload("res://scripts/mass_haul.gd")
var graph
var caption: Label
var coverage_label: Label
var csv_button: Button
var csv_dialog: FileDialog
var report={}
var revision_provider: Callable
var result_revision=-1

func _ready():
 title="누가토량도 / 구간별 절토−성토"
 min_size=Vector2i(950,560)
 close_requested.connect(hide)
 var margin=MarginContainer.new()
 margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 for side in ["left","right","top","bottom"]:margin.add_theme_constant_override("margin_"+side,12)
 add_child(margin)
 var root=VBoxContainer.new()
 margin.add_child(root)
 var toolbar=HBoxContainer.new()
 root.add_child(toolbar)
 var fit_button=Button.new()
 fit_button.text="전체 맞춤"
 fit_button.pressed.connect(func():graph.fit())
 toolbar.add_child(fit_button)
 csv_button=Button.new()
 csv_button.text="누가토량 CSV 저장"
 csv_button.disabled=true
 csv_button.pressed.connect(func():csv_dialog.popup_centered_ratio(0.7))
 toolbar.add_child(csv_button)
 caption=Label.new()
 caption.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 root.add_child(caption)
 coverage_label=Label.new()
 root.add_child(coverage_label)
 for text in ["상승: 절토 / 하강: 성토 우세 · 붉은 영역 제외 · 구간별 0 재시작 · 토량변화율/운반/배분/비용 보정 없음", "휠: 가로 확대 · 가운데: 이동 · 클릭: 유효 측점 이동 · 더블클릭: 전체 맞춤"]:
  var note=Label.new()
  note.text=text
  root.add_child(note)
 graph=Diagram.new()
 graph.size_flags_vertical=Control.SIZE_EXPAND_FILL
 graph.clip_contents=true
 graph.station_selected.connect(func(station):station_selected.emit(station))
 root.add_child(graph)
 csv_dialog=FileDialog.new()
 csv_dialog.access=FileDialog.ACCESS_FILESYSTEM
 csv_dialog.file_mode=FileDialog.FILE_MODE_SAVE_FILE
 csv_dialog.filters=PackedStringArray(["*.csv ; Segmented mass haul CSV"])
 csv_dialog.file_selected.connect(export_csv)
 add_child(csv_dialog)
 invalidate()

func invalidate():
 report={}
 result_revision=-1
 if graph!=null:graph.set_data({})
 if csv_button!=null:csv_button.disabled=true
 if coverage_label!=null:coverage_label.text=""
 if caption!=null:caption.text="토공량 창에서 현재 설계의 수량을 다시 계산하세요."

func show_report(value,revision):
 if value.is_empty() or not value.get("ok",false) or revision_provider.call()!=revision:
  invalidate()
  return false
 report=value
 result_revision=revision
 graph.set_data(Diagram.build_data(report.sections))
 csv_button.disabled=graph.data.rows.is_empty()
 caption.text="평균단면법 · 측점 %.1fm / 반폭 %.1fm / 횡단 %.1fm · 유효 %.1f/%.1fm (%.2f%%)" % [report.station_step,report.half_width,report.lateral_step,report.covered_length,report.total_length,report.coverage*100]
 coverage_label.text="연속 유효 %d구간 · 제외 %d구간 · 누계는 각 구간 시작 기준" % [graph.data.segments.size(),report.excluded_intervals]
 popup_centered(Vector2i(1100,650))
 return true

func export_csv(path):
 if report.is_empty() or result_revision!=revision_provider.call():
  invalidate()
  return false
 var temporary=path+".tmp_"+str(Time.get_ticks_usec())
 var file=FileAccess.open(temporary,FileAccess.WRITE)
 if file==null:
  caption.text="CSV 파일을 열지 못했습니다."
  return false
 file.store_buffer(PackedByteArray([239,187,191]))
 file.store_csv_line(PackedStringArray(["method","station_step_m","half_width_m","lateral_step_m","coverage_ratio","station_m","segment_id","row_kind","segment_cut_m3","segment_fill_m3","segment_cut_minus_fill_m3","interval_start_m"]))
 for row in graph.data.rows:
  var cells=PackedStringArray()
  for value in ["average_end_area",report.station_step,report.half_width,report.lateral_step,report.coverage,row.station,row.segment,row.kind,row.cut,row.fill,row.net,row.interval_start]:cells.append("" if value==null else str(value))
  file.store_csv_line(cells)
 file.flush()
 var error=file.get_error()
 file.close()
 if error!=OK or DirAccess.rename_absolute(temporary,path)!=OK:
  DirAccess.remove_absolute(temporary)
  caption.text="CSV 저장 실패 · 기존 파일은 보존됩니다."
  return false
 caption.text="구간별 누가토량 CSV 저장 완료 · 제외 구간 수량은 빈 셀입니다."
 return true
