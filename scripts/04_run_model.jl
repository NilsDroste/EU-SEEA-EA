"""
Script 04: End-to-end model run.

Loads processed data, assembles the EE-MRIO + SFC model,
solves for shadow prices, and writes results for the paper.

Run after scripts 01–03 have populated data/processed/.
"""

using CSV, DataFrames, LinearAlgebra
using Pkg; Pkg.activate(joinpath(@__DIR__, ".."))
include(joinpath(@__DIR__, "..", "src", "EUSEEAShadow.jl"))
using .EUSEEAShadow

const PROC_DIR = joinpath(@__DIR__, "..", "data", "processed")
const RES_DIR  = joinpath(@__DIR__, "..", "data", "results")
mkpath(RES_DIR)

# ---------------------------------------------------------------------------
# 1. Load MRIO inputs
# ---------------------------------------------------------------------------

function load_mrio(year::Int=2019)
    A_path = joinpath(PROC_DIR, "figaro_A_$(year).csv")
    F_path = joinpath(PROC_DIR, "figaro_F_$(year).csv")
    x_path = joinpath(PROC_DIR, "figaro_x_$(year).csv")

    if !isfile(A_path)
        error("MRIO data not found at $A_path — run scripts 01 and 02 first.")
    end

    A = Matrix(CSV.read(A_path, DataFrame, header=false))
    F = vec(Matrix(CSV.read(F_path, DataFrame, header=false)))
    x = vec(Matrix(CSV.read(x_path, DataFrame, header=false)))

    regions = ["NUTS2_$(i)" for i in 1:240]  # replace with actual labels
    sectors = ["NACE_$(i)"  for i in 1:64]

    return MRIOModel(A .* x', F, regions, sectors)
end

# ---------------------------------------------------------------------------
# 2. Load ecosystem accounts
# ---------------------------------------------------------------------------

function load_ecosystem_accounts()
    R_path   = joinpath(PROC_DIR, "R_matrix.csv")
    mac_path = joinpath(PROC_DIR, "es_metadata.csv")
    K_path   = joinpath(PROC_DIR, "ecosystem_extent.csv")

    if !isfile(R_path)
        error("R matrix not found — run script 03 first.")
    end

    R   = Matrix(CSV.read(R_path, DataFrame, header=false))
    meta = CSV.read(mac_path, DataFrame)
    K   = vec(Matrix(CSV.read(K_path, DataFrame, header=false)))

    return EcosystemAccounts(
        R, K,
        K .* 0.05,          # stub regen rates — replace with empirical estimates
        meta.label,
        meta.mac_eur,
    )
end

# ---------------------------------------------------------------------------
# 3. Solve shadow prices and simulate dynamics
# ---------------------------------------------------------------------------

function run_model(year::Int=2019)
    @info "Loading MRIO model (year=$year)..."
    m = load_mrio(year)

    @info "Loading ecosystem accounts..."
    ea = load_ecosystem_accounts()

    @info "Solving for gross output..."
    X = total_output(m)

    @info "Computing sustainability gap..."
    gap = sustainability_gap(ea, X)
    @info "Unsustainable ES flows: $(sum(gap .> 0)) / $(length(gap))"

    @info "Solving shadow prices..."
    n = size(m.A, 1)
    V = X .* 0.4   # stub: 40% value-added share — replace with FIGARO V vector
    result = solve_shadow_prices(ea, m, V)

    @info "Shadow prices (€/unit):"
    for (label, p) in zip(result.P_shadow_label, result.P_shadow)
        @info "  $label: $(round(p, digits=2))"
    end

    # Write results
    res_df = DataFrame(
        es_label  = result.P_shadow_label,
        p_shadow  = result.P_shadow,
    )
    CSV.write(joinpath(RES_DIR, "shadow_prices_$(year).csv"), res_df)
    @info "Results written to data/results/shadow_prices_$(year).csv"

    return result
end

run_model()
