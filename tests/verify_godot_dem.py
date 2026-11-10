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
source_meta=data['Source']
binary=destination.parent/data['SourceFile']
full=np.fromfile(binary,dtype='<f4').reshape(source_meta['Ny'],source_meta['Nx'])
assert full.size>data['Nx']*data['Ny']
assert np.nanmax(np.abs(full-120))<0.01
assert np.isnan(full).any()
assert abs((data['Nx']-1)*data['Dx']-(source_meta['Nx']-1)*source_meta['Dx'])<1e-6
assert abs((data['Ny']-1)*data['Dy']-(source_meta['Ny']-1)*source_meta['Dy'])<1e-6
assert data['OriginX']==source_meta['OriginX'] and data['OriginY']==source_meta['OriginY']
# Failed conversion must preserve an existing destination.
previous=destination.read_bytes()
result=subprocess.run([sys.executable,str(root/'godot/project/tools/import_dem.py'),str(folder/'missing.tif'),str(destination)],capture_output=True)
assert result.returncode!=0 and destination.read_bytes()==previous
print('PASS Godot DEM importer: bounded grid, metric CRS, elevation, NoData, atomic output')
print(source)

# A source spike between preview samples must remain available for height queries.
ridge=folder/'ridge_fixture.tif'
values=np.full((1025,1025),100,dtype='float32')
values[511,511]=300
with rasterio.open(ridge,'w',driver='GTiff',width=1025,height=1025,count=1,dtype='float32',crs='EPSG:5179',transform=from_origin(1000000,2000000,30,30),nodata=-32768) as ds:
    ds.write(values,1)
rdest=folder/'ridge_fixture.json'
subprocess.run([sys.executable,str(root/'godot/project/tools/import_dem.py'),str(ridge),str(rdest)],check=True)
r=json.loads(rdest.read_text())
fine=np.fromfile(rdest.parent/r['SourceFile'],dtype='<f4').reshape(r['Source']['Ny'],r['Source']['Nx'])
assert fine.shape==(1025,1025) and fine[511,511]==300
assert max(h for h in r['Heights'] if h is not None)==100
assert r['Source']['Min']==100 and r['Source']['Max']==300
print('PASS full-resolution ridge preserved while absent from the aligned preview')
