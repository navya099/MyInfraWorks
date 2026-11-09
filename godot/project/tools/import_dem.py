import argparse, json, os, tempfile
import numpy as np
import rasterio
from rasterio.warp import calculate_default_transform, reproject, Resampling
from affine import Affine

def convert(source, destination, max_grid=513):
    if not 17 <= max_grid <= 2049:
        raise ValueError('Grid limit must be between 17 and 2049')
    with rasterio.open(source) as ds:
        if not ds.crs:
            raise ValueError('DEM has no coordinate reference system')
        transform, width, height = calculate_default_transform(ds.crs, 'EPSG:5179', ds.width, ds.height, *ds.bounds)
        scale = max(1.0, max(width, height) / max_grid)
        out_width, out_height = max(2, round(width / scale)), max(2, round(height / scale))
        transform = transform * Affine.scale(width / out_width, height / out_height)
        grid = np.full((out_height, out_width), np.nan, dtype='float32')
        reproject(rasterio.band(ds, 1), grid, src_transform=ds.transform, src_crs=ds.crs, src_nodata=ds.nodata,
                  dst_transform=transform, dst_crs='EPSG:5179', dst_nodata=float('nan'), resampling=Resampling.bilinear)
        if not np.isfinite(grid).any():
            raise ValueError('DEM has no valid heights')
        data = dict(Nx=out_width, Ny=out_height, Dx=abs(transform.a), Dy=abs(transform.e),
                    OriginX=transform.c+transform.a/2, OriginY=transform.f+transform.e/2,
                    Crs='EPSG:5179', Name=source, Preview=True,
                    Heights=[float(h) if np.isfinite(h) else None for h in grid.flat])
    folder = os.path.dirname(os.path.abspath(destination))
    fd, temporary = tempfile.mkstemp(dir=folder, suffix='.json')
    try:
        with os.fdopen(fd, 'w', encoding='utf-8') as stream:
            json.dump(data, stream, allow_nan=False)
        os.replace(temporary, destination)
    finally:
        if os.path.exists(temporary):
            os.remove(temporary)

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('source')
    parser.add_argument('destination')
    parser.add_argument('--max-grid', type=int, default=513)
    args = parser.parse_args()
    convert(args.source, args.destination, args.max_grid)
