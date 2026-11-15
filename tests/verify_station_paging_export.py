"""Verify actual export from the final partial page includes the full result."""
from pathlib import Path
import csv
import sys
root=Path(sys.argv[1]) if len(sys.argv)>1 else Path("work/godot-appdata/Godot/app_userdata/MyInfraWorks")
path=root/"station-paging-ui.csv"
assert path.read_bytes().startswith(b"\xef\xbb\xbf")
with path.open(encoding="utf-8-sig",newline="") as f:
    reader=csv.DictReader(f)
    assert len(reader.fieldnames)==21
    rows=list(reader)
assert len(rows)==1201
assert [float(r["station_m"]) for r in rows]==list(range(1201))
for row in rows:
    sta=float(row["station_m"])
    assert float(row["local_east_m"])==600+sta
    assert float(row["local_south_m"])==1000
    assert float(row["station_step_m"])==1
assert "start" in rows[0]["events"] and "end" in rows[-1]["events"]
print("PASS STATION PAGING CSV: export from last one-row page contains all 1201 ordered stations, UTF-8 BOM, 21 columns and original coordinates")
