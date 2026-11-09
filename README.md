# MyInfraWorks

MyInfraWorks는 infraworks 대체 프레임워크를 개발하는 프로젝트입니다.

대한민국 SRTM 30m DEM을 활용한 Windows용 개략 노선설계 도구를 개발합니다. 목표 범위는 기본계획·예비타당성 검토 수준의 평면·종단선형, 종단·횡단 뷰, 지형 메시, 실시간 절성토 지형 미리보기입니다.

## 현재 상태

- `legacy/wpf`: 작동하는 WPF 시제품 0.2. DEM 열기, 직선 노선 작성, 계획고 변경, 종단·횡단·3D 표시, 단순 사면, 프로젝트 저장·복원을 지원합니다.
- `godot`: Godot + C++ 편집기 시제품 0.3. DEM 지형, Orbit/Pan/Zoom, 평면 노선, 종단 계획고 드래그, 횡단, 단순 절성토, 프로젝트 저장을 지원합니다. 지형은 타일로 나누고 C++ 작업 스레드에서 계산하며, 노선의 영향 구간만 갱신합니다.
- `tests`: WPF 계산 검사와 두 DEM 변환기 검사입니다. Godot 네이티브·편집기 검사는 아래 명령을 참조하세요.

## 준비

- Windows x64
- Visual Studio 2022: C++ 데스크톱 개발, MSVC v143, Windows SDK/UCRT
- Python 3.11 이상 / Git
- Godot 4.7.2 표준 Windows 버전
- WPF 시제품에만 .NET 9 SDK 필요

```powershell
git clone --recurse-submodules https://github.com/navya099/MyInfraWorks.git
cd MyInfraWorks
python -m pip install -r requirements-dev.txt
```

이미 복제했다면 `git submodule update --init --recursive`를 실행합니다. Godot 실행 파일은 별도로 설치합니다. `godot-cpp`는 검증한 4.5 API 커밋으로 고정되어 있고, 해당 확장의 Godot 4.7.2 로드를 확인했습니다. 의존성 소스의 라이선스는 해당 서브모듈을 참조하세요.

## WPF 시제품 실행

```powershell
dotnet run --project legacy/wpf/KRoadPrototype.csproj -c Release
```

시작 시 합성 지형이 표시됩니다. `DEM 열기`로 GeoTIFF를 선택합니다.

1. 평면 지형 안을 차례대로 클릭해 노선 점을 추가합니다.
2. 종단에서 클릭하면 측점상 가장 가까운 제어점의 계획고가 바뀝니다.
3. 폭·높이 보정·사면비를 입력하고 적용합니다. 사면비는 H:V입니다.
4. 횡단 슬라이더로 측점을 선택합니다. 초록은 원지반, 주황은 계획입니다.
5. 3D에서 드래그로 회전하고 휠로 확대합니다.
6. `.kroad` 형식으로 저장하고 다시 열 수 있습니다.

실제 DEM 로드는 Python의 rasterio를 사용합니다. EPSG:5179 수평 좌표계로 재투영하고 최대 161×161 격자로 축소합니다. 높이는 미터라고 가정하고 수직 기준 변환은 하지 않습니다. 원본 DEM을 수정하지 않습니다.

제한: DEM 한 타일, 직선 연결 노선·구배, 단순 사면만 지원합니다. 원곡선·완화곡선·종단곡선·편경사·토공량·실행 취소는 아직 없습니다. 축소 격자보다 좁은 도로·사면의 3D 표현은 부정확할 수 있습니다. 복잡한 사면 중첩과 도로 끝단 사면은 처리하지 않습니다.

## Godot C++ 빌드 및 검증

저장소 루트에서 실행합니다.

```powershell
python -m SCons -C godot platform=windows target=template_debug arch=x86_64 build_profile=build_profile.json -j4
```

생성 파일은 `godot/project/bin/kroad_core.windows.template_debug.x86_64.dll`입니다. 아래 `godot` 명령은 설치한 Godot 실행 파일 경로로 바꿔 실행해도 됩니다.

```powershell
godot --headless --path godot/project --editor --import --quit
godot --headless --path godot/project --script verify.gd
```

정상 출력: `PASS NATIVE CORE`. 타일 경계 높이·법선, NoData, 절성토, 잘못된 입력과 메시 생성을 검사합니다.

## 검사

```powershell
dotnet run --project tests/CoreTests -c Release
python tests/verify_dem.py
```

합성 DEM 검사는 `work/`에 임시 TIFF를 생성합니다. 사용자 DEM의 정확도를 검증하는 검사는 아닙니다.

## 다음 개발 범위

원본 해상도 높이 데이터와 화면 LOD를 분리하고, 도로 주변 삼각망을 세분화합니다. 이후 평면·종단곡선과 다중 DEM 타일을 추가합니다.

## 저장소 관리

DEM 원본, 사용자 프로젝트, Godot 실행 파일, 빌드 결과와 캐시는 커밋하지 않습니다. 기능 단위로 빌드·검사 후 커밋합니다. 현재 코드의 동작 여부와 계획 중인 기능을 구분해 기록합니다.


## Godot 편집기 0.3 실행

C++ 빌드 후 실행합니다.

```powershell
godot --path godot/project
```

이 PC에서는 `run-godot.cmd`를 두 번 클릭해도 됩니다. 런처는 형제 폴더의 Godot 4.7.2 실행 파일을 찾습니다. 다른 PC에서는 `GODOT_BIN` 환경 변수로 실행 파일 경로를 지정하세요. 런처가 시작한 프로세스의 사용자 데이터는 저장소의 무시된 `work/appdata/`에 둡니다. 전역 환경 설정은 바꾸지 않습니다.

- 평면 클릭: 노선 점 추가. 마지막 점 취소 / 노선 초기화 지원.
- 종단에서 드래그: 수평 측점상 가까운 제어점의 계획고 변경. 드래그 동안 세로 축 범위는 고정됩니다.
- 3D 왼쪽 드래그: Orbit. 오른쪽 또는 가운데 드래그: Pan. 휠: Zoom.
- 폭·높이 보정·사면비 변경 후 적용. 횡단 슬라이더로 측점 선택.
- `.kroadg`로 저장·불러오기. WPF의 `.kroad` 형식과는 다릅니다.
- 새 DEM 또는 프로젝트를 열면 현재 설계를 교체합니다. 작업을 먼저 저장하세요.

DEM 가져오기는 Python/rasterio를 작업 스레드에서 실행합니다. EPSG:5179, 최대 513×513 축소 격자를 사용하며, 원본 30m 해상도를 항상 유지하는 방식은 아닙니다. 높이는 미터로 가정하며 수직 기준을 변환하지 않습니다. 한 파일만 지원합니다.

C++는 지형 높이 보간, 계획지형 높이, 타일별 위치·법선·색상·인덱스를 생성합니다. 평면·종단선형은 아직 직선 연결이며 측점 샘플링과 도로 리본 표시는 GDScript에 있습니다. 곡선 설계, 토공량, 편경사와 복잡한 사면 처리는 미구현입니다. 축소 지형의 좁은 도로 주변은 아직 충분히 세분화되지 않았고, 도로 리본과 지형이 일부 겹쳐 보일 수 있습니다. 원지형/계획지형의 비교 토글은 없습니다.

렌더링 메시 한 타일은 32×32 셀입니다. 변경 전·후 노선의 보수적인 영향 범위에 해당하는 타일만 계산합니다. 영향 범위는 노선 전체 구간의 사면을 포함하므로, 긴 노선은 많은 타일을 다시 계산할 수 있습니다. 편집 요청은 버전으로 구분해 오래된 계산 결과를 버립니다. GPU 메시 반영은 프레임당 최대 2개 타일로 제한합니다. 드래그 중 도로/차트가 먼저 변하고 지형은 계산 완료 후 따라옵니다. 카메라 조작은 계산과 메시 생성에 관여하지 않습니다.

## Godot 추가 검증

```powershell
python tests/verify_godot_dem.py
godot --headless --path godot/project -- --smoke
godot --headless --path godot/project -- --dem-smoke "C:/absolute/path/to/MyInfraWorks/work/godot_fixture.tif"
godot --path godot/project -- --visual-test "C:/absolute/path/to/preview.png"
```

`verify_godot_dem.py`가 합성 GeoTIFF를 `work/godot_fixture.tif`에 생성합니다. 파일은 버전 관리에서 제외됩니다. 편집기 검사는 비동기 지형 생성, 연속 표고 수정, 카메라 독립성, 부분 갱신, 저장 복원을 검사합니다.

개발 PC(GTX 1060 6GB, OpenGL Compatibility)의 관측값:

- 합성 161×161 지형·노선 3점: 실제 렌더링 Orbit 120프레임 평균 13.33ms, p95 13.46ms. Orbit 중 지형 업로드 0회.
- C++ 전체 513×513 지형 256타일 배열 생성: 약 289ms. GPU 업로드·표시 시간은 제외한 값입니다.
- 합성 GeoTIFF에서 가져온 208타일 지형: 짧은 노선의 연속 계획고 변경 시 4타일 갱신. 최종 높이 반영 및 초기화 복원 검사 통과.
- 같은 208타일 지형을 실제 렌더링하면서 종단 드래그와 Orbit을 함께 실행한 60프레임: 중앙값 13.33ms, p95 13.42ms. 해당 노선의 갱신은 6타일.

이 값은 합성 데이터의 개발 측정이며 사용자 SRTM 원본에서의 정확도나 일정한 FPS를 보장하지 않습니다. 개발 샌드박스에서 인증서 저장소 읽기 경고가 발생하지만 로컬 계산·렌더링 검사는 통과했습니다.
