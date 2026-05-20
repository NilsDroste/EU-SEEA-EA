"""
Script 06: Build biophysical ecosystem intensity matrix R from INCA SUT use tables.

R[e, (country, sector)] = INCA_use[e, country, sector] / FIGARO_output[country, sector]

where output[country, sector] = sum over NUTS2 regions within country of x[NUTS2, sector].

Then R[e, (NUTS2, sector)] = R[e, (country, sector)]  [uniform within-country intensity]

Input:
  data/raw/inca/suts/All SUT -- shared/<ES>/<es>_use_2018_<unit>.csv
  data/processed/figaro_x.csv
  data/processed/figaro_sectors.csv

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
    # MACs are in million€ per physical unit of ES use, consistent with R matrix units
    # R[e,j] = physical_unit_per_million€; so P_shadow in million€/physical_unit is correct
    # Physical-unit conversions: kt = 1000 tonnes; k_m3 = 1000 m³
    # - €/tonne × (1 million€/10^6€) × (10^3 tonne/kt) = 10^-3 million€/kt
    # - €/m³ × (1 million€/10^6€) × (10^3 m³/k_m³) = 10^-3 million€/k_m³
    # - €/kg × (1 million€/10^6€) × (10^6 kg/kt) = 1 million€/kt
    # - monetary ES (million€ SUT units): MAC is dimensionless ratio (= 1.0 for full cost recovery)

    (id="carbon_seq",    label="Carbon sequestration",      dir="Carbon sequestration",
     file="carbon_sequestration_use_2018_1000_tonnes.csv",  unit="kt_CO2",
     mac_eur=0.085,  # 85 €/tonne CO2eq → 0.085 million€/kt (EU ETS 2017 ≈ €5-15; 85 is 2022 level, kept as upper bound)
     inca_sector="global_soc"),

    (id="crop_poll",     label="Crop pollination",           dir="Crop pollination",
     file="crop_pollination_use_2018_1000_tonnes.csv",       unit="kt_crop",
     mac_eur=0.15,   # 150 €/tonne pollination restoration cost → 0.15 million€/kt (managed hive cost basis)
     inca_sector="agriculture"),

    (id="crop_prov",     label="Crop provision",             dir="Crop provision",
     file="crop_provision_use_2018_1000_tonnes.csv",         unit="kt_DM",
     mac_eur=0.12,   # 120 €/tonne dry matter → 0.12 million€/kt (restoration cost basis)
     inca_sector="agriculture"),

    (id="wood_prov",     label="Wood provision",             dir="Wood provision",
     file="wood_provision_use_2018_1000_m3.csv",             unit="k_m3",
     mac_eur=0.045,  # 45 €/m³ timber → 0.045 million€/k_m³ (afforestation cost basis)
     inca_sector="forestry"),

    (id="flood_ctrl",    label="Flood control",              dir="Flood control",
     file="flood_control_use_2018_million_euro.csv",         unit="meur",
     mac_eur=1.0,    # monetary; 1 million€ of flood control costs 1 million€ to restore
     inca_sector="services"),

    (id="soil_ret",      label="Soil retention",             dir="Soil retention",
     file="soil_retention_use_2018_1000_tonnes.csv",         unit="kt_soil",
     mac_eur=0.008,  # 8 €/tonne → 0.008 million€/kt (nutrient replacement cost basis)
     inca_sector="agriculture"),

    (id="water_purif",   label="Water purification",         dir="Water purification",
     file="water_purification_use_2018_1000_tonnes.csv",     unit="kt_N",
     mac_eur=12.0,   # 12 €/kg N = 12 million€/kt N (wastewater treatment cost basis)
     inca_sector="agriculture"),

    (id="nat_tourism",   label="Nature-based recreation",    dir="Nature-based recreation",
     file="nature_based_recreation_use_2018_visits.csv", unit="k_visits",
     mac_eur=0.05,   # 50 €/visit ecosystem restoration cost → 0.05 million€/k_visits
     inca_sector="services"),

    (id="hab_species",   label="Habitat and species maintenance", dir="Habitat and species maintencance",
     file="habitat_and_species_maintenance_use_2018_million_euro.csv", unit="meur",
     mac_eur=1.0,    # monetary; full cost recovery assumption
     inca_sector="global_soc"),
]

# INCA sector → FIGARO-REG 10-sector mapping
# For sectors mapping to multiple FIGARO sectors, split evenly (proxy — refine with output shares)
const INCA_TO_FIGARO = Dict(
    "agriculture" => ["A"],
    "forestry"    => ["A"],
    "industry"    => ["B_E", "F"],
    "services"    => ["G_I", "J", "K", "L", "M_N", "O_Q", "R_U"],
    "households"  => ["P3_S14"],   # household final demand
    "global_soc"  => ["A","B_E","F","G_I","J","K","L","M_N","O_Q","R_U"],  # broadcast
)

# ---------------------------------------------------------------------------
# Load FIGARO output vector and sector index
# ---------------------------------------------------------------------------

x_df  = CSV.read(joinpath(PROC_DIR, "figaro_x.csv"), DataFrame)
sec_df = CSV.read(joinpath(PROC_DIR, "figaro_sectors.csv"), DataFrame)

# Country code from NUTS2: first 2 chars
x_df.country = [r[1:2] for r in x_df.region]

# Country × sector aggregate output (for intensity denominator)
x_country = combine(groupby(x_df, [:country, :sector]), :output_meur => sum => :output_meur)

N_eu = nrow(sec_df)
E    = length(ES_DEFS)

# ---------------------------------------------------------------------------
# Build R matrix: E × N_eu
# ---------------------------------------------------------------------------

R = zeros(E, N_eu)

function load_inca_use(es)
    path = joinpath(SUTS_DIR, es.dir, es.file)
    !isfile(path) && (@warn "Missing: $(es.file)"; return nothing)
    df = CSV.read(path, DataFrame, header=2)
    # columns: Country, agriculture, forestry, industry, services, households, global_soc,
    #          [ecosystem type cols...], Total
    rename!(df, 1 => :country)
    df = df[df.country .!= "EU", :]   # drop EU aggregate row
    select!(df, :country,
            names(df, r"agriculture|forestry|industry|services|households|global") ...)
    return df
end

for (e_idx, es) in enumerate(ES_DEFS)
    use_df = load_inca_use(es)
    use_df === nothing && continue

    figaro_sectors = INCA_TO_FIGARO[es.inca_sector]
    n_fig_sectors  = length(figaro_sectors)

    for row in eachrow(use_df)
        ctry = row.country

        # Get INCA use value for this ES's primary sector
        inca_col = es.inca_sector == "global_soc" ? "global society" :
                   es.inca_sector == "global_soc" ? "global society" :
                   replace(es.inca_sector, "_" => " ")
        # Robustly find the column
        col_name = findfirst(c -> occursin(es.inca_sector == "global_soc" ? "global" :
                                           es.inca_sector, lowercase(string(c))),
                              names(use_df))
        col_name === nothing && continue
        use_val = row[col_name]
        (ismissing(use_val) || use_val == 0.0) && continue

        for fig_sec in figaro_sectors
            # Country-level output for this sector
            x_row = filter(r -> r.country == ctry && r.sector == fig_sec, x_country)
            isempty(x_row) && continue
            x_ctry_sec = x_row.output_meur[1]
            x_ctry_sec <= 0 && continue

            # Intensity: ES physical units per million € of output
            intensity = (use_val / n_fig_sectors) / x_ctry_sec

            # Apply to all NUTS2 within this country and sector
            mask = (sec_df.region .!= "") .&
                   [s[1:2] == ctry && s_sec == fig_sec
                    for (s, s_sec) in zip(sec_df.region, sec_df.sector)]
            R[e_idx, mask] .= intensity
        end
    end
    @info "Built R row $(e_idx)/$(E): $(es.label)"
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
