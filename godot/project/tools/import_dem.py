"""Build an aligned preview plus a full-resolution metric float32 height grid."""
import argparse
import json
import os
import tempfile
import uuid
from pathlib import Path
import numpy as np
import rasterio
from rasterio.warp import calculate_default_transform, reproject, Resampling


def preview_grid(grid, width, height):
    """Sample exactly the same first/last pixel centers as the source grid."""
    ny, nx = grid.shape
    gx, gy = np.linspace(0, nx-1, width), np.linspace(0, ny-1, height)
    ix, iy = np.minimum(gx.astype(int), nx-2), np.minimum(gy.astype(int), ny-2)
    u, v = (gx-ix)[None, :], (gy-iy)[:, None]
    a, b = grid[iy[:, None], ix], grid[iy[:, None], ix+1]
    c, d = grid[iy[:, None]+1, ix], grid[iy[:, None]+1, ix+1]
    return ((1-u)*(1-v)*a + u*(1-v)*b + (1-u)*v*c + u*v*d).astype('float32')


def convert(source, destination, max_grid=513):
    if not 17 <= max_grid <= 2049:
        raise ValueError('Grid limit must be between 17 and 2049')
    folder = Path(destination).resolve().parent
    source_path = folder / ('heights_' + uuid.uuid4().hex + '.f32')
    metadata_temp = None
    committed = False
    try:
        with rasterio.open(source) as ds:
            if not ds.crs:
                raise ValueError('DEM has no coordinate reference system')
            transform, width, height = calculate_default_transform(ds.crs, 'EPSG:5179', ds.width, ds.height, *ds.bounds)
            if width < 2 or height < 2 or width*height > 64_000_000:
                raise ValueError('Metric DEM exceeds the 64 million sample limit; crop before importing')
            grid = np.full((height, width), np.nan, dtype='float32')
            reproject(rasterio.band(ds, 1), grid, src_transform=ds.transform, src_crs=ds.crs, src_nodata=ds.nodata,
                      dst_transform=transform, dst_crs='EPSG:5179', dst_nodata=float('nan'), resampling=Resampling.bilinear)
            finite = np.isfinite(grid)
            if not finite.any():
                raise ValueError('DEM has no valid heights')
            scale = max(1.0, max(width-1, height-1)/(max_grid-1))
            pw, ph = max(2, round((width-1)/scale)+1), max(2, round((height-1)/scale)+1)
            preview = preview_grid(grid, pw, ph)
            origin_x, origin_y = transform.c+transform.a/2, transform.f+transform.e/2
            source_meta = dict(Nx=width, Ny=height, Dx=abs(transform.a), Dy=abs(transform.e),
                               OriginX=origin_x, OriginY=origin_y, Min=float(grid[finite].min()), Max=float(grid[finite].max()))
            grid.astype('<f4', copy=False).tofile(source_path)
            data = dict(Nx=pw, Ny=ph, Dx=abs(transform.a)*(width-1)/(pw-1), Dy=abs(transform.e)*(height-1)/(ph-1),
                        OriginX=origin_x, OriginY=origin_y, Crs='EPSG:5179', Name=source, Preview=True,
                        Source=source_meta, SourceFile=source_path.name, SourceEncoding='float32-le',
                        Heights=[float(h) if np.isfinite(h) else None for h in preview.flat])
        fd, metadata_temp = tempfile.mkstemp(dir=folder, suffix='.json')
        with os.fdopen(fd, 'w', encoding='utf-8') as stream:
            json.dump(data, stream, allow_nan=False)
        os.replace(metadata_temp, destination)
        committed = True
    finally:
        if metadata_temp and os.path.exists(metadata_temp):
            os.remove(metadata_temp)
        if not committed and source_path.exists():
            source_path.unlink()


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('source')
    parser.add_argument('destination')
    parser.add_argument('--max-grid', type=int, default=513)
    args = parser.parse_args()
    convert(args.source, args.destination, args.max_grid)
