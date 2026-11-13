# 노선 측점표 — 0.17

측점표 창에서 간격을 정하고 산출한 뒤 CSV로 저장합니다. 정규 간격(기본20m, 허용0.1~10000m)에 시·종점, PI/PVI 대응 측점, 평면 요소 경계와 종단곡선 양 끝을 추가합니다. 1e−6m 이내의 동일 측점은 합치고 경계 태그를 함께 남깁니다. 정규 측점과 거의 일치하는 경계는 실제 경계 측점을 우선합니다. 경계 포함 최대20,000행이며 초과하면 간격을 늘려야 합니다.

## 산출값과 좌표

중심 계획고는 네이티브 sample(s)의 실제 종단고 + 계획고 보정입니다. 종단곡선에서 PVI 제어고와 다를 수 있습니다. 지반고는 원본 해상도 계산용 DEM의 쌍선형 보간값이고, 차이는 중심 계획고−지반고입니다. 이 차이는 한 점의 높이 차이이며 토공량이 아닙니다.

종단구배는 sample(s)의 구배×100이고 곡률은 평면 곡률(1/m)입니다. 반경은 곡률 절댓값의 역수로, 완화곡선에서는 변합니다. |곡률|<1e−12이면 직선으로 취급해 반경을 정의하지 않습니다. CSV에 무한대나 0 반경으로 쓰지 않습니다. 좌/우 가장자리 계획고는 중심고−폭/2×해당 하향구배/100입니다.

로컬 X는 동쪽, Y는 남쪽으로 증가하며 원점은 DEM 북서쪽 첫 픽셀 중심입니다. 재투영된 DEM의 원점 정보가 있으면 E=OriginX+X, N=OriginY−Y로 EPSG:5179 좌표를 추가합니다. 원점이 없는 지형은 LOCAL로 쓰고 E/N은 빈 셀입니다. 이 내보내기는 추가 좌표 변환이나 수직 기준 변환을 하지 않습니다. 표고는 입력 DEM/설계의 m 단위를 가정합니다.

## CSV 21열

```text
station_m,local_east_m,local_south_m,easting_m,northing_m,crs,center_elevation_m,ground_elevation_m,center_minus_ground_m,grade_pct,curvature_per_m,radius_m,left_edge_elevation_m,right_edge_elevation_m,ground_status,station_step_m,width_m,offset_m,left_down_pct,right_down_pct,events
```

UTF-8 BOM이며 각 행에 간격·폭·보정·좌우 구배를 함께 기록합니다. ground_status는 ok/nodata입니다. 범위 밖/NoData 지반은 ground_elevation_m과 center_minus_ground_m을 비우고 계획고·구배·좌표는 유지합니다. 반경 빈 셀은 직선, E/N 빈 셀은 LOCAL 여부로 구분합니다. 화면의 결측은 NA이며 직선은 직선으로 표시합니다.

events는 start/end/regular/PI/PVI/geometry_boundary/vertical_curve_start/vertical_curve_end 태그를 |로 연결합니다. 한 측점에 여러 경계가 겹칠 수 있습니다. CSV의 PI 측점은 곡선상 대응 측점이며 실제 접선 교점 PI의 평면좌표를 내보내는 행은 아닙니다. UI에서는 경계 이름을 한글로 표시합니다.

## 결과 유효성

행 선택은 현재 측점으로 이동하며 화면 맞춤은 기존 버튼을 사용합니다. 설계·이력·수량을 변경하지 않습니다. 산출은 불변 스냅샷과 별도 스레드를 사용하고 설계/DEM/간격 변경 시 결과를 무효화합니다. 이전 작업이 끝나도 revision/설정 세대가 다르면 버립니다. 출력 시 revision을 다시 확인하고 임시 파일 작성 후 교체합니다.

표와 간격은 현재 실행에만 유지하며 프로젝트 v6나 네이티브 DLL v016은 바꾸지 않습니다. 이 CSV는 측점별 선형 정보이며 토공량 CSV(별도21열)와 서로 다른 형식입니다. 정규 간격 사이의 지형 극값을 모두 포함하는 상세 종단 조사 결과는 아닙니다.
