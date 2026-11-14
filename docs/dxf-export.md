# CAD DXF 출력 — 0.18

상단 DXF 버튼에서 좌표 모드와 최대 측점 간격을 선택해 산출하고 DXF 저장을 누릅니다. 기본은 로컬 동/북과 10m입니다. 원점 정보가 없는 지형에서는 EPSG 모드를 선택할 수 없습니다. 산출 작업은 별도 스레드에서 수행합니다.

## 좌표와 표고

로컬 출력은 (X=동쪽 로컬 X, Y=−남쪽 로컬 Y, Z=설계 표고)입니다. 앱의 측점표 CSV 로컬 Y는 남쪽 양수이므로 DXF 로컬 Y와 부호가 다릅니다. EPSG:5179 모드에서는 (E=OriginX+X, N=OriginY−Y, Z=설계 표고)로 저장합니다. 좌표 숫자를 출력하며 CAD의 지리좌표계 설정 객체를 생성하지 않습니다.

Z는 실제 종단고+계획고 보정이고 가장자리는 도로 폭과 해당 횡단구배를 반영합니다. 3D 화면에서 리본을 띄우는 0.5m는 포함하지 않습니다. 입력 표고의 수직 기준 변환도 하지 않습니다.

1 도면 단위는 1m의 좌표값입니다. 이 R12 출력에는 자동 삽입 단위 코드를 넣지 않으므로 CAD에서 가져오기 단위를 m로 지정합니다. 출력 파일의 ASCII 주석에도 UNITS=METERS와 좌표 모드를 기록합니다.

## 레이어와 근사

| 레이어 | 내용 | 색상 |
|---|---|---|
| KROAD_CENTER | 실제 선형 중심선 | 노랑 |
| KROAD_LEFT | 진행 방향 좌측 도로 가장자리 | 하늘색 |
| KROAD_RIGHT | 진행 방향 우측 도로 가장자리 | 초록 |

세 레이어 모두 열린 3D POLYLINE입니다. POLYLINE의 70=8, VERTEX의 70=32와 SEQEND를 사용하는 형식은 [Autodesk POLYLINE 명세](https://help.autodesk.com/cloudhelp/2024/ENU/AutoCAD-DXF/files/GUID-ABF6B778-BE20-4B49-9B58-A94E64CEFFF3.htm), [VERTEX 명세](https://help.autodesk.com/cloudhelp/2024/ENU/AutoCAD-DXF/files/GUID-0741E831-599E-4CBF-91E1-8ADBCFD6556D.htm), [R12 DXF 명세](https://damassets.autodesk.net/content/dam/autodesk/www/developer-network/platform-technologies/autocad-dxf-archive/acad_r12_dxf.pdf)를 참고했습니다.

네이티브 선형의 적응 분할 측점과 정규 측점을 합쳐 정확한 double sample(s)의 좌표·접선·표고를 사용합니다. 최대 측점 간격은 중심선 호장 기준이며 3D 가장자리 정점 간 거리의 한계라는 뜻은 아닙니다. 시·종점과 곡선 경계를 유지합니다. 선분 근사이므로 CAD의 원호·스플라인·Civil 3D Alignment 객체는 아닙니다. 무곡선 PI의 가장자리도 법선 기반 선분이며 별도 모서리 정리/교차 정리는 하지 않습니다. 지형·사면·횡단 도면은 출력하지 않습니다.

간격은 1~25m이고 적응 분할을 포함해 최대30,000측점(90,000정점)입니다. 복잡한 노선은 간격을 늘려도 기본 분할이 제한을 넘을 수 있습니다.

## 유효성·검증

설계/DEM/최대 간격/좌표 모드 변경 시 결과를 폐기하고 출력 시 revision을 다시 확인합니다. 임시 파일을 완성한 뒤 교체합니다. 산출과 출력은 설계·이력·프로젝트 v6 형식을 바꾸지 않습니다. 네이티브 DLL은 v018이며 이전 실행 창을 닫고 재실행해야 합니다.

Godot 검사가 user:// 아래 로컬·EPSG·원곡선·포물선 DXF 예제를 생성하고 DXF FIXTURES 경로를 출력합니다. tests/verify_dxf_export.py는 별도 판독기 ezdxf 1.3.0으로 그 경로를 읽어 감사 오류/수정 0건을 검사합니다. 세 레이어/3D 플래그, 수치 좌표·북쪽 부호·설계고, 점 간격, 중심 원반경300m/좌290m/우310m, 포물선 제어고와 실제고 차이를 확인합니다. 예제는 합성 데이터입니다. 판독 검증은 ezdxf에서 수행했습니다.

검증 패키지는 requirements-dev.txt에만 포함되며 Godot 실행/내보내기 자체는 Python이나 ezdxf에 의존하지 않습니다.
