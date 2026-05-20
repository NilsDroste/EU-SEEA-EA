"""
Script 03: Process INCA ecosystem service flow accounts and build the R matrix.

INCA (Integrated Natural Capital Accounting) provides ecosystem service
Supply and Use tables aligned with SEEA EA conventions. These are the
primary source for the biophysical coefficient matrix R (E×N).

Data source: https://ec.europa.eu/eurostat (search: "ecosystem accounts")
Contact: estat-environment@ec.europa.eu for NUTS2-disaggregated tables.

Supplementary sources:
  - ICOS carbon fluxes: https://www.icos-cp.eu/ (API access available)
  - EMEP air quality: https://www.emep.int/ (free download)
  - European Forest Accounts (EFA): Eurostat / UNECE

Outputs:
  data/processed/R_matrix.csv         -- ecosystem intensity matrix (E×N)
  data/processed/es_metadata.csv      -- ES labels and units
  data/processed/mac_vector.csv       -- marginal abatement costs (€/unit)
"""

using CSV, DataFrames, Statistics
using Pkg; Pkg.activate(joinpath(@__DIR__, ".."))

const PROC_DIR = joinpath(@__DIR__, "..", "data", "processed")
mkpath(PROC_DIR)

# ---------------------------------------------------------------------------
# Ecosystem service taxonomy (aligned with SEEA EA / CICES v5.1)
# ---------------------------------------------------------------------------

const ES_TAXONOMY = [
    ("prov_freshwater",    "Freshwater provisioning",         "m³/year"),
    ("prov_timber",        "Timber provisioning",             "m³/year"),
    ("prov_biomass",       "Wild-crop biomass provisioning",  "t DM/year"),
    ("reg_carbon",         "Carbon sequestration & storage",  "t CO₂eq/year"),
    ("reg_airquality",     "Air quality regulation",          "t PM₂.₅ avoided/year"),
    ("reg_water_purif",    "Water purification",              "kg N removed/year"),
    ("reg_pollination",    "Pollination",                     "index 0–1"),
    ("reg_flood_control",  "Flood attenuation",               "m³ water retained/year"),
    ("hab_species_hab",    "Species habitat provision",       "EQR index"),
]

# ---------------------------------------------------------------------------
# Marginal abatement cost (MAC) placeholders
# These will be replaced with empirical estimates from:
#   - EU LIFE programme restoration costs
#   - National habitat remediation assessments
#   - Literature: Sauer & Wossink (2012)
# ---------------------------------------------------------------------------

const MAC_PLACEHOLDER = Dict(
    "prov_freshwater"   => 0.50,   # €/m³
    "prov_timber"       => 45.0,   # €/m³
    "prov_biomass"      => 120.0,  # €/t DM
    "reg_carbon"        => 85.0,   # €/t CO₂eq (EU ETS reference)
    "reg_airquality"    => 30000.0, # €/t PM₂.₅
    "reg_water_purif"   => 12.0,   # €/kg N
    "reg_pollination"   => 1500.0, # €/index unit (per ha of pollinator habitat)
    "reg_flood_control" => 0.10,   # €/m³ retention capacity
    "hab_species_hab"   => 800.0,  # €/EQR unit (restoration cost proxy)
)

function build_es_metadata()
    df = DataFrame(
        es_id   = [t[1] for t in ES_TAXONOMY],
        label   = [t[2] for t in ES_TAXONOMY],
        unit    = [t[3] for t in ES_TAXONOMY],
        mac_eur = [MAC_PLACEHOLDER[t[1]] for t in ES_TAXONOMY],
    )
    return df
end

function build_R_matrix_stub(n_sectors::Int=64, n_regions::Int=240)
    # Placeholder: R will be populated from INCA tables once downloaded.
    E = length(ES_TAXONOMY)
    N = n_sectors * n_regions
    @warn "build_R_matrix_stub: returning zeros — replace with INCA data"
    return zeros(E, N)
end

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

es_meta = build_es_metadata()
CSV.write(joinpath(PROC_DIR, "es_metadata.csv"), es_meta)
@info "Wrote es_metadata.csv"

R = build_R_matrix_stub()
# CSV.write(joinpath(PROC_DIR, "R_matrix.csv"), DataFrame(R, :auto))  # large file
@info "R matrix stub shape: $(size(R))"
@info "Next: run 04_run_model.jl after populating data/processed/ with real data."
