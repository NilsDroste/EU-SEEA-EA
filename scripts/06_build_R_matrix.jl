"""
Script 06: Build biophysical ecosystem intensity matrix R from INCA SUT use tables.

R[e, (NUTS2, sector)] = share_NUTS2 * INCA_use[e, country] / x[NUTS2, sector]
                         (if spatial shares available for ES e)
                       = INCA_use[e, country, sector] / x[country, sector]
                         (uniform fallback if no spatial data)

Input:
  data/raw/inca/suts/All SUT -- shared/<ES>/<es>_use_2018_<unit>.csv
  data/processed/figaro_x.csv
  data/processed/figaro_sectors.csv
  data/processed/inca_nuts2_shares.csv   ← NUTS2 spatial shares from script 07

Output:
  data/processed/R_matrix.csv     -- E × N_eu (dense, million units per million €)
  data/processed/es_metadata.csv  -- ES labels, units, MACs

INCA sector → FIGARO-REG sector mapping:
  agriculture  → A
  forestry     → A  (merged in FIGARO-REG)
  industry     → B_E, F
  services     → G_I, J, K, L, M_N, O_Q, R_U
  households   → P3_S14 (treated as final demand row in R; not used in A-matrix block)
  global_soc   → distributes proportionally to all sectors (broadcast ES like climate reg)
"""

using CSV, DataFrames, Statistics
using Pkg; Pkg.activate(joinpath(@__DIR__, ".."))

const SUTS_DIR = joinpath(@__DIR__, "..", "data", "raw", "inca", "suts", "All SUT -- shared")
const PROC_DIR = joinpath(@__DIR__, "..", "data", "processed")

# ---------------------------------------------------------------------------
# INCA ecosystem service definitions
# ---------------------------------------------------------------------------

const ES_DEFS = [
    (id="carbon_seq",    label="Carbon sequestration",      dir="Carbon sequestration",
     file="carbon_sequestration_use_2018_1000_tonnes.csv",  unit="kt_CO2",
     mac_eur=0.085,  # 85 €/tonne CO2eq → 0.085 million€/kt
     inca_sector="global_soc",
     share_col="global_climate_regulation"),

    (id="crop_poll",     label="Crop pollination",           dir="Crop pollination",
     file="crop_pollination_use_2018_1000_tonnes.csv",       unit="kt_crop",
     mac_eur=0.15,   # 150 €/tonne → 0.15 million€/kt
     inca_sector="agriculture",
     share_col="crop_pollination"),

    (id="crop_prov",     label="Crop provision",             dir="Crop provision",
     file="crop_provision_use_2018_1000_tonnes.csv",         unit="kt_DM",
     mac_eur=0.12,   # 120 €/tonne → 0.12 million€/kt
     inca_sector="agriculture",
     share_col="crop_provision"),

    (id="wood_prov",     label="Wood provision",             dir="Wood provision",
     file="wood_provision_use_2018_1000_m3.csv",             unit="k_m3",
     mac_eur=0.045,  # 45 €/m³ → 0.045 million€/k_m³
     inca_sector="forestry",
     share_col="wood_provision"),

    (id="flood_ctrl",    label="Flood control",              dir="Flood control",
     file="flood_control_use_2018_million_euro.csv",         unit="meur",
     mac_eur=1.0,    # monetary; full cost recovery
     inca_sector="services",
     share_col="flood_control"),

    (id="soil_ret",      label="Soil retention",             dir="Soil retention",
     file="soil_retention_use_2018_1000_tonnes.csv",         unit="kt_soil",
     mac_eur=0.008,  # 8 €/tonne → 0.008 million€/kt
     inca_sector="agriculture",
     share_col="soil_retention"),

    (id="water_purif",   label="Water purification",         dir="Water purification",
     file="water_purification_use_2018_1000_tonnes.csv",     unit="kt_N",
     mac_eur=12.0,   # 12 €/kg N = 12 million€/kt N
     inca_sector="agriculture",
     share_col=nothing),   # no spatial GeoTIFF → uniform fallback

    (id="nat_tourism",   label="Nature-based recreation",    dir="Nature-based recreation",
     file="nature_based_recreation_use_2018_visits.csv",     unit="k_visits",
     mac_eur=0.05,   # 50 €/visit → 0.05 million€/k_visits
     inca_sector="services",
     share_col="nature_based_tourism"),

    (id="hab_species",   label="Habitat and species maintenance", dir="Habitat and species maintencance",
     file="habitat_and_species_maintenance_use_2018_million_euro.csv", unit="meur",
     mac_eur=1.0,    # monetary; full cost recovery
     inca_sector="global_soc",
     share_col=nothing),   # no spatial GeoTIFF → uniform fallback
]

# INCA sector → FIGARO-REG 10-sector mapping
const INCA_TO_FIGARO = Dict(
    "agriculture" => ["A"],
    "forestry"    => ["A"],
    "industry"    => ["B_E", "F"],
    "services"    => ["G_I", "J", "K", "L", "M_N", "O_Q", "R_U"],
    "households"  => ["P3_S14"],
    "global_soc"  => ["A","B_E","F","G_I","J","K","L","M_N","O_Q","R_U"],
)

# ---------------------------------------------------------------------------
# Load FIGARO output vector, sector index, and spatial shares
# ---------------------------------------------------------------------------

x_df   = CSV.read(joinpath(PROC_DIR, "figaro_x.csv"), DataFrame)
sec_df = CSV.read(joinpath(PROC_DIR, "figaro_sectors.csv"), DataFrame)

# Country code from NUTS2: first 2 chars
x_df.country = [r[1:2] for r in x_df.region]

# Country × sector aggregate output (for uniform fallback)
x_country = combine(groupby(x_df, [:country, :sector]), :output_meur => sum => :output_meur)

# NUTS2 spatial shares: nuts_id × ES_column → within-country share
shares_df = CSV.read(joinpath(PROC_DIR, "inca_nuts2_shares.csv"), DataFrame)
share_cols = names(shares_df)

N_eu = nrow(sec_df)
E    = length(ES_DEFS)

# Build fast lookup: (nuts_id, col_name) → share
# Key: (nuts2::String, col::String) → Float64
share_lookup = Dict{Tuple{String,String}, Float64}()
for row in eachrow(shares_df)
    for col in share_cols
        col in ("nuts_id", "cntr") && continue
        share_lookup[(row.nuts_id, col)] = row[col]
    end
end

# Fast NUTS2×sector index: (nuts2, sector) → row index in sec_df / x_df
sec_index = Dict{Tuple{String,String}, Int}()
for j in 1:N_eu
    sec_index[(sec_df.region[j], sec_df.sector[j])] = j
end

# NUTS2-level output lookup: (nuts2, sector) → output_meur
x_nuts2 = Dict{Tuple{String,String}, Float64}()
for row in eachrow(x_df)
    x_nuts2[(row.region, row.sector)] = row.output_meur
end

# ---------------------------------------------------------------------------
# Build R matrix: E × N_eu
# ---------------------------------------------------------------------------

R = zeros(E, N_eu)

function load_inca_use(es)
    path = joinpath(SUTS_DIR, es.dir, es.file)
    !isfile(path) && (@warn "Missing: $(es.file)"; return nothing)
    df = CSV.read(path, DataFrame, header=2)
    rename!(df, 1 => :country)
    df = df[df.country .!= "EU", :]
    select!(df, :country,
            names(df, r"agriculture|forestry|industry|services|households|global") ...)
    return df
end

for (e_idx, es) in enumerate(ES_DEFS)
    use_df = load_inca_use(es)
    use_df === nothing && continue

    figaro_sectors = INCA_TO_FIGARO[es.inca_sector]
    n_fig_sectors  = length(figaro_sectors)
    has_spatial    = es.share_col !== nothing && es.share_col in share_cols

    for row in eachrow(use_df)
        ctry = row.country

        # Robustly find the INCA sector column
        col_name = findfirst(c -> occursin(es.inca_sector == "global_soc" ? "global" :
                                           es.inca_sector, lowercase(string(c))),
                              names(use_df))
        col_name === nothing && continue
        use_val = row[col_name]
        (ismissing(use_val) || use_val == 0.0) && continue

        for fig_sec in figaro_sectors
            if has_spatial
                # ---- NUTS2-level disaggregation using spatial shares ----
                # Find all NUTS2 regions in this country × sector
                for (k, v) in sec_index
                    nuts2, sec = k
                    (length(nuts2) < 2 || nuts2[1:2] != ctry || sec != fig_sec) && continue
                    share = get(share_lookup, (nuts2, es.share_col), 0.0)
                    share == 0.0 && continue
                    x_j = get(x_nuts2, (nuts2, fig_sec), 0.0)
                    x_j <= 0 && continue
                    # Intensity: (share of national use allocated to this NUTS2) / NUTS2 output
                    intensity = (share * use_val / n_fig_sectors) / x_j
                    R[e_idx, sec_index[(nuts2, fig_sec)]] = intensity
                end
            else
                # ---- Uniform within-country fallback ----
                x_row = filter(r -> r.country == ctry && r.sector == fig_sec, x_country)
                isempty(x_row) && continue
                x_ctry_sec = x_row.output_meur[1]
                x_ctry_sec <= 0 && continue
                intensity = (use_val / n_fig_sectors) / x_ctry_sec
                mask = [s[1:2] == ctry && s_sec == fig_sec
                        for (s, s_sec) in zip(sec_df.region, sec_df.sector)]
                R[e_idx, mask] .= intensity
            end
        end
    end
    mode_str = has_spatial ? "NUTS2 spatial" : "uniform country"
    @info "Built R row $(e_idx)/$(E): $(es.label) [$(mode_str)]"
end

# ---------------------------------------------------------------------------
# Save R matrix and metadata
# ---------------------------------------------------------------------------

R_df = DataFrame(R, ["$(sec_df.region[j])_$(sec_df.sector[j])" for j in 1:N_eu])
insertcols!(R_df, 1, :es_id   => [e.id    for e in ES_DEFS])
insertcols!(R_df, 2, :es_label => [e.label for e in ES_DEFS])
CSV.write(joinpath(PROC_DIR, "R_matrix.csv"), R_df)

meta_df = DataFrame(
    es_id    = [e.id    for e in ES_DEFS],
    label    = [e.label for e in ES_DEFS],
    unit     = [e.unit  for e in ES_DEFS],
    mac_eur  = [e.mac_eur for e in ES_DEFS],
    inca_sector = [e.inca_sector for e in ES_DEFS],
)
CSV.write(joinpath(PROC_DIR, "es_metadata.csv"), meta_df)

@info "R matrix shape: $(size(R))"
@info "Non-zero entries: $(sum(R .!= 0))"
@info "Saved R_matrix.csv and es_metadata.csv"
@info "Next: run 04_run_model.jl"
