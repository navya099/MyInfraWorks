import json,sys
import numpy as np
import rasterio
from rasterio.warp import calculate_default_transform,reproject,Resampling
from affine import Affine
with rasterio.open(sys.argv[1]) as ds:
 if not ds.crs: raise ValueError('DEM has no CRS')
 tr,w,h=calculate_default_transform(ds.crs,'EPSG:5179',ds.width,ds.height,*ds.bounds)
 scale=max(w,h)/161
 w,h=max(2,round(w/scale)),max(2,round(h/scale))
 tr=tr*Affine.scale(scale,scale)
 a=np.full((h,w),np.nan,dtype='float32')
 reproject(rasterio.band(ds,1),a,src_transform=ds.transform,src_crs=ds.crs,src_nodata=ds.nodata,dst_transform=tr,dst_crs='EPSG:5179',dst_nodata=float('nan'),resampling=Resampling.bilinear)
 if not np.isfinite(a).any(): raise ValueError('No valid elevations')
 data=dict(Nx=w,Ny=h,Dx=abs(tr.a),Dy=abs(tr.e),OriginX=tr.c+tr.a/2,OriginY=tr.f+tr.e/2,Heights=[float(v) if np.isfinite(v) else None for v in a.flat],Name=sys.argv[1])
 with open(sys.argv[2],'w',encoding='utf-8') as f:json.dump(data,f,allow_nan=False)
