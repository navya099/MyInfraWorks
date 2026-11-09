import importlib.util, json, subprocess, sys
from pathlib import Path
import numpy as np
import rasterio
from rasterio.transform import from_origin
root=Path(__file__).resolve().parents[1]
folder=root/'work';folder.mkdir(exist_ok=True)
source=folder/'godot_fixture.tif'
with rasterio.open(source,'w',driver='GTiff',width=1201,height=1201,count=1,dtype='int16',crs='EPSG:4326',transform=from_origin(127,37,1/3600,1/3600),nodata=-32768) as ds:
    values=np.full((1201,1201),120,dtype='int16');values[:60,:60]=-32768;ds.write(values,1)
destination=folder/'godot_fixture.json'
subprocess.run([sys.executable,str(root/'godot/project/tools/import_dem.py'),str(source),str(destination)],check=True)
data=json.loads(destination.read_text())
valid=[v for v in data['Heights'] if v is not None]
assert max(data['Nx'],data['Ny'])<=513
assert abs(sum(valid)/len(valid)-120)<0.01
assert any(v is None for v in data['Heights'])
assert data['Crs']=='EPSG:5179' and data['Dx']>0 and data['Dy']>0
# Failed conversion must preserve an existing destination.
previous=destination.read_bytes()
result=subprocess.run([sys.executable,str(root/'godot/project/tools/import_dem.py'),str(folder/'missing.tif'),str(destination)],capture_output=True)
assert result.returncode!=0 and destination.read_bytes()==previous
print('PASS Godot DEM importer: bounded grid, metric CRS, elevation, NoData, atomic output')
print(source)
