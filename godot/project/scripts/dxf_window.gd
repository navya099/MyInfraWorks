extends "res://scripts/station_table.gd"
const Geometry=preload("res://scripts/dxf_geometry.gd")
var coordinate_mode: OptionButton

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
 hint.text="중심선·좌/우 가장자리 3D 폴리라인 · 1 도면 단위=1m(CAD 가져오기 단위 m) · 곡선은 선분 근사"
 status.text="좌표와 간격을 지정하고 산출하세요."

func open_export():
 var state=snapshot_provider.call()
 coordinate_mode.set_item_disabled(1,not Geometry.has_origin(state.snapshot.source))
 if coordinate_mode.is_item_disabled(1) and coordinate_mode.selected==1:
  coordinate_mode.select(0)
  invalidate()
 popup_centered(Vector2i(1150,540))

func start_calculation():
 if worker!=null:
  status.text="이전 산출 종료를 기다려 주세요."
  return
 var state=snapshot_provider.call()
 invalidate()
 requested_revision=state.revision
 requested_generation=generation
 status.text="DXF 산출 중"
 worker=Thread.new()
 if worker.start(Geometry.calculate_job.bind(state.snapshot,interval.value,coordinate_mode.selected))!=OK:
  worker=null
  status.text="작업 스레드를 시작하지 못했습니다."

func _process(_delta):
 if worker==null or worker.is_alive():return
 var completed=worker.wait_to_finish()
 worker=null
 if requested_revision!=revision_provider.call() or requested_generation!=generation:
  status.text="변경 전 산출 결과를 버렸습니다. 다시 산출하세요."
  return
 if not completed.ok:
  status.text="산출 실패: "+str(completed.get("error","unknown"))
  return
 result=completed
 result_revision=requested_revision
 csv_button.disabled=false
 status.text="%d개 정점 / %d개 측점 · %s · %.1fms" % [result.vertices,result.stations,"로컬 동/북" if result.crs=="LOCAL_EAST_NORTH" else result.crs,result.ms]
 table.text="DXF R12 ASCII / 3D POLYLINE\nKROAD_CENTER: 중심선\nKROAD_LEFT: 진행 방향 좌측 도로 가장자리\nKROAD_RIGHT: 진행 방향 우측 도로 가장자리\n\n노선 %.3fm / 최대 측점 간격 %.1fm\n단위 m · X 동쪽 / Y 북쪽 / Z 설계 표고\n3D 화면의 표시용 높이 보정은 제외합니다.\n지형·사면·Civil 3D 선형 객체는 포함하지 않습니다." % [result.length,result.spacing]

func select_row():
 pass

func export_csv(path):
 if result.is_empty() or result_revision!=revision_provider.call():
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
