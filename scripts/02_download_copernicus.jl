"""
Script 02: Download ecosystem extent and condition data from Copernicus / EEA.

Data sources:
  - CORINE Land Cover (CLC): https://land.copernicus.eu/pan-european/corine-land-cover
    Access: free download via Copernicus Land Monitoring Service portal.
    Resolution: 100m raster, all EU member states.
    Years available: 1990, 2000, 2006, 2012, 2018.

  - EEA Water Framework Directive status: https://www.eea.europa.eu/
    (Water quality index for surface and groundwater bodies)

  - LUCAS Topsoil: https://joint-research-centre.ec.europa.eu/projects-compendium/lucas_en
    Access: free via JRC Data Catalogue.

  - Common Bird Index / Butterfly Index (EBCC): https://pecbms.info/
    Access: aggregated indices freely available; raw data requires data agreement.

Outputs:
  data/raw/clc/           -- CORINE Land Cover GeoTIFFs
  data/raw/eea/           -- EEA water quality
  data/raw/lucas/         -- LUCAS topsoil CSV
  data/processed/ecosystem_extent.csv    -- ha by NUTS2 × EUNIS type
  data/processed/ecosystem_condition.csv -- condition indices by NUTS2 × ES type
"""

using Downloads, CSV, DataFrames
using Pkg; Pkg.activate(joinpath(@__DIR__, ".."))

const RAW_DIR_CLC   = joinpath(@__DIR__, "..", "data", "raw", "clc")
const RAW_DIR_EEA   = joinpath(@__DIR__, "..", "data", "raw", "eea")
const RAW_DIR_LUCAS = joinpath(@__DIR__, "..", "data", "raw", "lucas")

mkpath.([RAW_DIR_CLC, RAW_DIR_EEA, RAW_DIR_LUCAS])

# ---------------------------------------------------------------------------
# CORINE Land Cover
# ---------------------------------------------------------------------------

const CLC_YEARS = [2012, 2018]

function download_clc(year::Int)
    # CLC is distributed as ZIP via the Copernicus portal.
    # Direct download requires accepting the licence; use the portal URL below.
    @info """
    CORINE Land Cover $year: manual download required.
    1. Go to: https://land.copernicus.eu/pan-european/corine-land-cover/clc$year
    2. Register (free) and download the 100m GeoTIFF for EU.
    3. Place the extracted raster at: $(RAW_DIR_CLC)/CLC$(year)_V2020_20u1.tif
    """
end

# ---------------------------------------------------------------------------
# LUCAS Topsoil
# ---------------------------------------------------------------------------

function download_lucas()
    # LUCAS Topsoil 2018 is available as CSV from JRC Data Catalogue
    url = "https://esdac.jrc.ec.europa.eu/content/lucas2018-topsoil-data"
    @info """
    LUCAS Topsoil: manual download required.
    1. Go to: $url
    2. Register and download lucas_2018_topsoil.csv
    3. Place at: $(RAW_DIR_LUCAS)/lucas_2018_topsoil.csv
    """
end

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

for year in CLC_YEARS
    download_clc(year)
end
download_lucas()

@info "Copernicus download instructions printed. Follow the manual steps above."
@info "Next: run 03_process_inca.jl"
