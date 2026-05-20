"""
Script 01: Download FIGARO MRIO tables.

TWO DATA SOURCES — use both:

A) FIGARO-REG (10 sectors × NUTS2 regions, 2017) — DIRECTLY DOWNLOADABLE
   URL: https://jeodpp.jrc.ec.europa.eu/ftp/jrc-opendata/FIGARO-REG/2017/IOI_10SEC_D2.csv
   Size: ~700MB. Format: flat CSV (REFREG, ROWII, COUNTERPARTREG, COLII, OBSVALUE).
   Sectors: A, B_E, F, G_I, J, K, L, M_N, O_Q, R_U
   After download, run scripts/05_build_figaro_mrio.jl to build A, F, x matrices.

B) FIGARO national (64 sectors × 27+ countries, 2010-2022) — MANUAL DOWNLOAD
   Location: CIRCABC platform → "Integrated Global Accounts Expert Group" → FIGARO database
   URL: https://circabc.europa.eu  (search for "Integrated Global Accounts Expert Group")
   Format: Parquet (full detail) + CSV + Excel (21-sector summary)
   Contact: ESTAT-IGA@ec.europa.eu for access questions.
   After download, place Parquet files in data/raw/figaro_national/

Outputs (after running this script + 05_build_figaro_mrio.jl):
  data/raw/figaro_reg/IOI_10SEC_D2.csv
  data/processed/figaro_A_sparse.csv
  data/processed/figaro_F.csv
  data/processed/figaro_x.csv
  data/processed/figaro_sectors.csv
"""

using Downloads
using Pkg; Pkg.activate(joinpath(@__DIR__, ".."))

const FIGARO_REG_URL = "https://jeodpp.jrc.ec.europa.eu/ftp/jrc-opendata/FIGARO-REG/2017/IOI_10SEC_D2.csv"
const RAW_DIR_REG    = joinpath(@__DIR__, "..", "data", "raw", "figaro_reg")
const RAW_DIR_NAT    = joinpath(@__DIR__, "..", "data", "raw", "figaro_national")

mkpath(RAW_DIR_REG)
mkpath(RAW_DIR_NAT)

# ---------------------------------------------------------------------------
# Part A: FIGARO-REG (automatic download)
# ---------------------------------------------------------------------------

outpath = joinpath(RAW_DIR_REG, "IOI_10SEC_D2.csv")

if isfile(outpath) && filesize(outpath) > 600_000_000  # ~700MB expected
    @info "FIGARO-REG already downloaded: $(round(filesize(outpath)/1e6)) MB"
else
    @info "Downloading FIGARO-REG (~700MB, may take 10-15 minutes)..."
    try
        Downloads.download(FIGARO_REG_URL, outpath)
        @info "Downloaded: $(round(filesize(outpath)/1e6)) MB"
    catch e
        @warn "Download failed: $e"
        @info "Try resuming with: curl -C - -o $outpath \"$FIGARO_REG_URL\""
    end
end

# ---------------------------------------------------------------------------
# Part B: FIGARO national (manual)
# ---------------------------------------------------------------------------

@info """

FIGARO national tables (64-sector, 2010-2022): MANUAL DOWNLOAD REQUIRED
───────────────────────────────────────────────────────────────────────────
1. Go to: https://circabc.europa.eu
2. Search for public group: "Integrated Global Accounts Expert Group"
3. Navigate to folder: FIGARO database
4. Download the Parquet files for the years needed (2017 recommended)
5. Place downloaded files in: $(RAW_DIR_NAT)/

Once downloaded, a separate parsing script (to be written) will build
the full 64-sector A matrix using Julia's Parquet.jl package.

Contact for access: ESTAT-IGA@ec.europa.eu
"""

@info "FIGARO download script complete."
@info "Next: run 05_build_figaro_mrio.jl to parse FIGARO-REG into model matrices."
