"""
Script 01: Download FIGARO MRIO tables from Eurostat/JRC.

FIGARO-REG provides 64-sector × 240+ NUTS2 region trade matrices.
Data is available at:
  https://ec.europa.eu/eurostat/web/esa-supply-use-input-output-tables/figaro

Access: The national-level FIGARO tables are freely downloadable via the
Eurostat bulk download facility. The NUTS2-disaggregated FIGARO-REG tables
require registration with the JRC (contact: jrc-figaro@ec.europa.eu).

Outputs:
  data/raw/figaro/  -- FIGARO ZIP files (national) or CSV (regional)
  data/processed/figaro_A.csv       -- technical coefficient matrix
  data/processed/figaro_F.csv       -- final demand vector
  data/processed/figaro_x.csv       -- gross output vector
  data/processed/figaro_metadata.json
"""

using HTTP, Downloads, CSV, DataFrames, JSON3
using Pkg; Pkg.activate(joinpath(@__DIR__, ".."))

const FIGARO_BASE_URL = "https://ec.europa.eu/eurostat/api/dissemination/sdmx/2.1/data/"
const RAW_DIR = joinpath(@__DIR__, "..", "data", "raw", "figaro")
const PROC_DIR = joinpath(@__DIR__, "..", "data", "processed")

mkpath(RAW_DIR)
mkpath(PROC_DIR)

# ---------------------------------------------------------------------------
# Step 1: Download national FIGARO tables (symmetric IO, product × product)
# ---------------------------------------------------------------------------

YEARS = [2019, 2020, 2021]  # update as new vintages are released

function download_figaro_national(year::Int)
    # Eurostat dataset code for symmetric IO tables: naio_10_cp1700
    filename = "figaro_nat_$(year).csv"
    outpath = joinpath(RAW_DIR, filename)
    if isfile(outpath)
        @info "Already downloaded: $filename"
        return outpath
    end
    # TODO: replace with actual Eurostat API endpoint once confirmed
    url = "$(FIGARO_BASE_URL)naio_10_cp1700?time=$(year)&format=CSV&lang=EN"
    @info "Downloading FIGARO national $year..."
    Downloads.download(url, outpath)
    return outpath
end

# ---------------------------------------------------------------------------
# Step 2: Load and construct A, F, x matrices
# ---------------------------------------------------------------------------

function build_leontief_inputs(year::Int)
    path = joinpath(RAW_DIR, "figaro_nat_$(year).csv")
    !isfile(path) && error("Run download step first: $path not found")
    df = CSV.read(path, DataFrame)

    # TODO: parse FIGARO format into Z (flows), x (output), F (final demand)
    # FIGARO uses NACE Rev.2 codes; rows = supplying industries, cols = using industries
    # Placeholder: return empty structures
    @warn "build_leontief_inputs: parsing stub — implement once raw data format is confirmed"
    return nothing
end

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

for year in YEARS
    try
        download_figaro_national(year)
    catch e
        @warn "Could not download FIGARO $year: $e"
        @info "Manual download: https://ec.europa.eu/eurostat/web/esa-supply-use-input-output-tables/figaro"
    end
end

@info "FIGARO download script complete. Check data/raw/figaro/ for downloaded files."
@info "Next: run 02_download_copernicus.jl"
