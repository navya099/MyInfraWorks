import json,subprocess,sys
from pathlib import Path
import numpy as np,rasterio
from rasterio.transform import from_origin
root=Path(__file__).resolve().parents[1]
(root/'work').mkdir(exist_ok=True)
f=root/'work'/'test_dem.tif'
with rasterio.open(f,'w',driver='GTiff',width=100,height=100,count=1,dtype='int16',crs='EPSG:4326',transform=from_origin(127,37,1/3600,1/3600),nodata=-32768) as ds:
 a=np.full((100,100),120,dtype='int16');a[:20,:20]=-32768;ds.write(a,1)
out=root/'work'/'test_dem.json'
subprocess.run([sys.executable,str(root/'legacy/wpf/dem_import.py'),str(f),str(out)],check=True)
d=json.loads(out.read_text()); valid=[v for v in d['Heights'] if v is not None]
assert max(d['Nx'],d['Ny'])<=161
assert abs(sum(valid)/len(valid)-120)<.01
assert d['Dx']>0 and d['Dy']>0
assert any(v is None for v in d['Heights'])
assert 500000<d['OriginX']<1500000
print('PASS GeoTIFF reprojection / metric grid / elevation / NoData / bounded preview')
