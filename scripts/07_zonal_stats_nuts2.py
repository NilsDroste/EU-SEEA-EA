"""
Script 07: Compute NUTS2-level zonal statistics from INCA use maps.

For each ecosystem service and each NUTS2 region, sums the physical use
values from the INCA 100m GeoTIFF maps (EPSG:3035) to produce a
NUTS2 × ES use table.

This gives spatial weights for distributing national INCA SUT values to
NUTS2 regions in the R matrix (used by script 06).

Strategy:
  - Reproject NUTS2 polygons from EPSG:4326 → EPSG:3035 (raster CRS)
  - For each NUTS2 polygon: windowed raster read + masked sum
  - Output: data/processed/inca_nuts2_use.csv

Requirements: rasterio (pip install rasterio --break-system-packages)

Run after: scripts/03_process_inca.jl (which downloads + extracts the ZIPs)
Run before: scripts/06_build_R_matrix.jl (which uses these spatial weights)
"""

import os, json, zipfile, tempfile
import numpy as np
import rasterio
import rasterio.features
import rasterio.warp
import rasterio.mask
from rasterio.crs import CRS
from rasterio.transform import from_bounds
from shapely.geometry import shape, mapping
from shapely.ops import transform as shapely_transform
import pyproj
from pyproj import Transformer

RAW_DIR  = os.path.join(os.path.dirname(__file__), "..", "data", "raw", "inca")
NUTS_FILE = os.path.join(os.path.dirname(__file__), "..", "data", "raw", "nuts2",
                         "NUTS_RG_01M_2021_4326_LEVL_2.geojson")
PROC_DIR = os.path.join(os.path.dirname(__file__), "..", "data", "processed")

# Ecosystem service definitions: (name, zip_name, tif_subpath)
# Using the 2018 'use' maps (physical units)
ES_DEFS = [
    ("global_climate_regulation", "GLOBAL_CLIMATE_REGULATION",
     "GLOBAL_CLIMATE_REGULATION/maps/use_sequestration/carbon-net-sequestration_map_use_tonnes_2018.tif"),
    ("crop_pollination",          "CROP_POLLINATION",
     "CROP_POLLINATION/maps/use/crop-pollination_map_use_tonnes_2018.tif"),
    ("wood_provision",            "WOOD_PROVISION",
     "WOOD_PROVISION/maps/use/wood-provision_map_use_m3_2018.tif"),
    ("flood_control",             "FLOOD_CONTROL",
     "FLOOD_CONTROL/maps/use/flood-control_map_use_hectare_2018.tif"),
    ("air_filtration",            "AIR_FILTRATION",
     "AIR_FILTRATION/maps/use/air-filtration_map_use_tonnes_2018.tif"),
    ("soil_retention",            "SOIL_RETENTION",
     "SOIL_RETENTION/maps/use/soil-retention_map_use_tonnes_2018.tif"),
    ("crop_provision",            "CROP_PROVISION",
     "CROP_PROVISION/maps/use/crop-provision_map_use_tonnes_2018.tif"),
    ("nature_based_tourism",      "NATURE-BASED_TOURISM",
     "NATURE-BASED_TOURISM/maps/use/tourism_map_supply_amountOvernightStays_2018.tif"),
]

RASTER_CRS = CRS.from_epsg(3035)
WGS84_CRS  = CRS.from_epsg(4326)


def load_nuts2_geometries():
    """Load NUTS2 polygons and reproject to EPSG:3035."""
    transformer = Transformer.from_crs("EPSG:4326", "EPSG:3035",
                                        always_xy=True)

    with open(NUTS_FILE) as f:
        gj = json.load(f)

    nuts2 = []
    for feat in gj["features"]:
        nuts_id = feat["properties"]["NUTS_ID"]
        eu_stat = feat["properties"].get("EU_STAT", "")
        # Keep only NUTS2 level (length 4) — includes EU27 + candidate countries
        if len(nuts_id) != 4:
            continue
        geom_wgs = shape(feat["geometry"])
        # Reproject geometry to EPSG:3035
        geom_3035 = shapely_transform(
            lambda x, y: transformer.transform(x, y),
            geom_wgs
        )
        nuts2.append({
            "nuts_id":  nuts_id,
            "cntr":     nuts_id[:2],
            "eu_stat":  eu_stat,
            "geom":     geom_3035,
        })

    print(f"Loaded {len(nuts2)} NUTS2 regions")
    return nuts2


def zonal_sum_from_zip(zip_path: str, tif_subpath: str, nuts2_list: list) -> dict:
    """
    Extract TIF from ZIP into temp dir, compute zonal sum per NUTS2 region.
    Returns dict {nuts_id: sum_value}.
    """
    results = {n["nuts_id"]: 0.0 for n in nuts2_list}

    if not os.path.exists(zip_path):
        print(f"  ZIP not found: {zip_path}")
        return results

    # Check ZIP integrity before trying to open (skip if still downloading)
    try:
        with zipfile.ZipFile(zip_path) as test_zf:
            test_zf.testzip()  # raises BadZipFile if incomplete
    except (zipfile.BadZipFile, Exception) as e:
        print(f"  ZIP invalid (still downloading?): {e}")
        return results

    with tempfile.TemporaryDirectory() as tmpdir:
        # Extract only the needed TIF
        with zipfile.ZipFile(zip_path) as zf:
            # Try exact filename match first
            target_name = tif_subpath.split("/")[-1]
            members = [m for m in zf.namelist() if m.endswith(target_name)]
            if not members:
                # Fallback: any 2018 .tif whose parent dir is exactly "use" (not "use_something")
                # Prefer files without -foreign or -national suffixes (pick totals)
                candidates = [m for m in zf.namelist()
                              if "2018" in m and m.endswith(".tif")
                              and m.split("/")[-2] == "use"]
                # Prefer total (no split suffix) over split files
                totals = [m for m in candidates
                          if not any(s in m for s in ["-foreign", "-national", "-domestic"])]
                members = totals if totals else candidates
            if not members:
                # Broad fallback: any 2018 use-related tif in physical units
                members = [m for m in zf.namelist()
                           if "2018" in m and m.endswith(".tif")
                           and any(d in m.split("/") for d in ["use", "use_sequestration",
                                                                "use_flow", "use_physical"])
                           and "monetary" not in m]
            if not members:
                print(f"  No 2018 use TIF found in {os.path.basename(zip_path)}")
                return results

            tif_member = members[0]
            print(f"  Extracting: {tif_member}")
            zf.extract(tif_member, tmpdir)
            tif_path = os.path.join(tmpdir, tif_member)

        with rasterio.open(tif_path) as src:
            nodata = src.nodata if src.nodata is not None else -9999.0
            print(f"  Raster: {src.width}x{src.height}, {src.crs}, nodata={nodata}")

            for n in nuts2_list:
                geom = n["geom"]
                if geom.is_empty:
                    continue
                geom_geojson = [mapping(geom)]
                try:
                    out_image, _ = rasterio.mask.mask(src, geom_geojson,
                                                      crop=True, nodata=nodata,
                                                      all_touched=False)
                    data = out_image[0].astype(np.float64)
                    valid = data[data != nodata]
                    results[n["nuts_id"]] = float(np.sum(valid[valid > 0]))
                except Exception:
                    pass  # polygon outside raster extent

    return results


def main():
    print("Loading NUTS2 geometries...")
    nuts2_list = load_nuts2_geometries()

    all_results = []  # list of {nuts_id, es_id, value}

    for es_id, zip_name, tif_subpath in ES_DEFS:
        zip_path = os.path.join(RAW_DIR, f"{zip_name}.zip")
        print(f"\nProcessing {es_id}...")
        results = zonal_sum_from_zip(zip_path, tif_subpath, nuts2_list)
        total = sum(results.values())
        nonzero = sum(1 for v in results.values() if v > 0)
        print(f"  Total: {total:.1f}, NUTS2 with data: {nonzero}/{len(nuts2_list)}")
        for nuts_id, val in results.items():
            all_results.append({"nuts_id": nuts_id, "es_id": es_id, "value": val})

    # Write long-format CSV
    import csv
    out_long = os.path.join(PROC_DIR, "inca_nuts2_use_long.csv")
    os.makedirs(PROC_DIR, exist_ok=True)
    with open(out_long, "w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=["nuts_id", "es_id", "value"])
        writer.writeheader()
        writer.writerows(all_results)
    print(f"\nSaved long-format: {out_long}")

    # Pivot to wide format: nuts_id × es_id
    nuts_ids = sorted(set(r["nuts_id"] for r in all_results))
    es_ids   = [es[0] for es in ES_DEFS]

    out_wide = os.path.join(PROC_DIR, "inca_nuts2_use_wide.csv")
    pivot = {n: {e: 0.0 for e in es_ids} for n in nuts_ids}
    for r in all_results:
        pivot[r["nuts_id"]][r["es_id"]] = r["value"]

    with open(out_wide, "w", newline="") as f:
        writer = csv.writer(f)
        writer.writerow(["nuts_id"] + es_ids)
        for n in nuts_ids:
            writer.writerow([n] + [pivot[n][e] for e in es_ids])
    print(f"Saved wide-format: {out_wide}")

    # Compute and save national shares (NUTS2 value / country total)
    out_shares = os.path.join(PROC_DIR, "inca_nuts2_shares.csv")
    with open(out_wide) as f:
        reader = csv.DictReader(f)
        rows = list(reader)

    # Country totals
    ctry_totals = {}
    for row in rows:
        ctry = row["nuts_id"][:2]
        if ctry not in ctry_totals:
            ctry_totals[ctry] = {e: 0.0 for e in es_ids}
        for e in es_ids:
            ctry_totals[ctry][e] += float(row[e])

    with open(out_shares, "w", newline="") as f:
        writer = csv.writer(f)
        writer.writerow(["nuts_id", "cntr"] + es_ids)
        for row in rows:
            ctry = row["nuts_id"][:2]
            shares = []
            for e in es_ids:
                total = ctry_totals[ctry][e]
                shares.append(float(row[e]) / total if total > 0 else 0.0)
            writer.writerow([row["nuts_id"], ctry] + shares)
    print(f"Saved NUTS2 spatial shares: {out_shares}")
    print("\nDone. These shares are used by script 06_build_R_matrix.jl.")


if __name__ == "__main__":
    main()
