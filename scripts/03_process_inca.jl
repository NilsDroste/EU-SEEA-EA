"""
Script 03: Download INCA ecosystem service accounts and prepare for R matrix construction.

INCA (Integrated Natural Capital Accounting, JRC) provides:
  - Supply and Use Tables (SUTs) for 8 ecosystem services at country level
    (EU-27, years: 2000, 2006, 2012, 2018) → used to build R matrix
  - High-resolution maps (GeoTIFFs) per NUTS2 region → for spatial disaggregation

Data access: All files are freely downloadable from the JRC FTP (no auth required).

JRC Dataset IDs:
  - SUTs (national, 2000-2018): https://data.jrc.ec.europa.eu/dataset/4cbd7c1e-6512-4ebe-8ca5-e08209cc3efb
  - Maps (NUTS2, 2000-2021):    https://data.jrc.ec.europa.eu/dataset/d810c03e-535f-4f48-879e-ef26c7c61e24

Outputs:
  data/raw/inca/SUTs_time_series_all.zip    (250KB, national SUTs — PRIMARY)
  data/raw/inca/suts/                        (extracted SUT CSVs)
  data/raw/inca/<ES>.zip                     (300-600MB each, NUTS2 maps — for spatial step)
  data/processed/es_metadata.csv
  → R matrix built by script 06_build_R_matrix.jl

Run order: 03 → 06 → 04
"""

using Downloads
using Pkg; Pkg.activate(joinpath(@__DIR__, ".."))

const RAW_DIR  = joinpath(@__DIR__, "..", "data", "raw", "inca")
const PROC_DIR = joinpath(@__DIR__, "..", "data", "processed")
mkpath(RAW_DIR)
mkpath(PROC_DIR)

# ---------------------------------------------------------------------------
# PRIMARY: National SUT time series (250KB — always download this first)
# ---------------------------------------------------------------------------

const SUTS_URL = "https://jeodpp.jrc.ec.europa.eu/ftp/jrc-opendata/MAES/INCA_update/LATEST/SUTs_ES_ALL/SUTs_time_series_all.zip"

function download_suts()
    out = joinpath(RAW_DIR, "SUTs_time_series_all.zip")
    if isfile(out) && filesize(out) > 100_000
        @info "SUTs already downloaded ($(filesize(out)) bytes)"
        return out
    end
    @info "Downloading INCA SUTs (national level, ~250KB)..."
    Downloads.download(SUTS_URL, out)
    @info "Downloaded $(filesize(out)) bytes"
    return out
end

# ---------------------------------------------------------------------------
# SPATIAL: Per-ES map ZIPs (300-600MB each) — download sequentially
# INCA 2021 update: adds year 2021 and improved maps
# ---------------------------------------------------------------------------

const ES_MAP_URLS = [
    ("GLOBAL_CLIMATE_REGULATION", "https://jeodpp.jrc.ec.europa.eu/ftp/jrc-opendata/MAES/INCA_2021_update/GLOBAL_CLIMATE_REGULATION.zip"),
    ("CROP_POLLINATION",          "https://jeodpp.jrc.ec.europa.eu/ftp/jrc-opendata/MAES/INCA_2021_update/CROP_POLLINATION.zip"),
    ("WOOD_PROVISION",            "https://jeodpp.jrc.ec.europa.eu/ftp/jrc-opendata/MAES/INCA_2021_update/WOOD_PROVISION.zip"),
    ("FLOOD_CONTROL",             "https://jeodpp.jrc.ec.europa.eu/ftp/jrc-opendata/MAES/INCA_2021_update/FLOOD_CONTROL.zip"),
    ("AIR_FILTRATION",            "https://jeodpp.jrc.ec.europa.eu/ftp/jrc-opendata/MAES/INCA_2021_update/AIR_FILTRATION.zip"),
    ("SOIL_RETENTION",            "https://jeodpp.jrc.ec.europa.eu/ftp/jrc-opendata/MAES/INCA_2021_update/SOIL_RETENTION.zip"),
    ("CROP_PROVISION",            "https://jeodpp.jrc.ec.europa.eu/ftp/jrc-opendata/MAES/INCA_2021_update/CROP_PROVISION.zip"),
    ("NATURE-BASED_TOURISM",      "https://jeodpp.jrc.ec.europa.eu/ftp/jrc-opendata/MAES/INCA_2021_update/NATURE-BASED_TOURISM.zip"),
]

function download_es_maps(; force::Bool=false)
    for (name, url) in ES_MAP_URLS
        out = joinpath(RAW_DIR, "$(name).zip")
        if !force && isfile(out) && filesize(out) > 100_000_000
            @info "$name: already downloaded ($(round(filesize(out)/1e6))MB)"
            continue
        end
        @info "Downloading $name (~300-600MB)..."
        try
            Downloads.download(url, out)
            sz = filesize(out)
            if sz < 10_000_000
                @warn "$name: suspiciously small ($(sz) bytes) — may be corrupt, retry"
            else
                @info "$name: $(round(sz/1e6))MB ✓"
            end
        catch e
            @warn "$name failed: $e"
            @info "Retry with: curl -C - -o $out \"$url\""
        end
    end
end

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

suts_path = download_suts()

# Extract SUTs if not already done
suts_dir = joinpath(RAW_DIR, "suts")
if !isdir(suts_dir) || isempty(readdir(suts_dir))
    @info "Extracting SUT CSVs..."
    run(`unzip -o $suts_path -d $suts_dir`)
end

@info "SUT tables extracted to: $suts_dir"
@info """

Spatial map downloads (optional — needed for NUTS2 disaggregation):
  Call download_es_maps() to download all map ZIPs sequentially (~3GB total).
  These are large and slow — download overnight or on a fast connection.
  WARNING: Do NOT run in parallel (causes corrupt ZIPs).

  julia> include("scripts/03_process_inca.jl")
  julia> download_es_maps()
"""

@info "Next: run 06_build_R_matrix.jl to build R from SUT tables."
