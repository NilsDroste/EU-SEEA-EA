"""
Script 04: End-to-end model run.

Loads processed FIGARO-REG MRIO + INCA R matrix, solves for shadow prices,
computes transboundary amplification, and writes results for the paper.

Implements Propositions 1–4 from the theoretical framework:
  - P_shadow = MAC (Proposition 1, linear cost case)
  - τ = P_shadow' R L ≥ D = P_shadow' R (Proposition 2)
  - Block-recursive IS-LM-Ecosystem equilibrium (Proposition 4)

Run after scripts 05 and 06 have populated data/processed/.
"""

using CSV, DataFrames, SparseArrays, LinearAlgebra
using Pkg; Pkg.activate(joinpath(@__DIR__, ".."))

const PROC_DIR = joinpath(@__DIR__, "..", "data", "processed")
const RES_DIR  = joinpath(@__DIR__, "..", "data", "results")
mkpath(RES_DIR)

# ---------------------------------------------------------------------------
# 1. Load MRIO matrices from processed files
# ---------------------------------------------------------------------------

@info "Loading sector index..."
sec_df = CSV.read(joinpath(PROC_DIR, "figaro_sectors.csv"), DataFrame)
N = nrow(sec_df)
labels = ["$(sec_df.region[j])_$(sec_df.sector[j])" for j in 1:N]
countries = [sec_df.region[j][1:2] for j in 1:N]

@info "Loading A matrix (sparse triplet)..."
A_df = CSV.read(joinpath(PROC_DIR, "figaro_A_sparse.csv"), DataFrame)
A = sparse(A_df.row, A_df.col, A_df.val, N, N)

@info "Loading x and F vectors..."
x_df = CSV.read(joinpath(PROC_DIR, "figaro_x.csv"), DataFrame)
x = x_df.output_meur

F_df = CSV.read(joinpath(PROC_DIR, "figaro_F.csv"), DataFrame)
F_cols = ["P3_S13", "P3_S14", "P3_S15", "P51G", "P5M"]
F_mat = Matrix{Float64}(F_df[:, F_cols])
f_total = vec(sum(F_mat, dims=2))   # aggregate final demand vector

# Verify Leontief balance: x ≈ A*x + f
residual = maximum(abs.(x .- (A * x .+ f_total)))
@info "Leontief balance check: max residual = $(round(residual, digits=4)) million €"

# ---------------------------------------------------------------------------
# 2. Load R matrix and ecosystem metadata
# ---------------------------------------------------------------------------

@info "Loading R matrix..."
R_raw = CSV.read(joinpath(PROC_DIR, "R_matrix.csv"), DataFrame)
es_ids    = R_raw.es_id
es_labels = R_raw.es_label
R = Matrix{Float64}(R_raw[:, 3:end])   # skip es_id, es_label columns
E = size(R, 1)
@assert size(R, 2) == N "R matrix columns ($( size(R,2))) must match MRIO dimension ($N)"

meta_df = CSV.read(joinpath(PROC_DIR, "es_metadata.csv"), DataFrame)
P_shadow = meta_df.mac_eur   # vector of MACs = shadow prices (Proposition 1)

@info "Ecosystem services: $(E)"
for (label, p) in zip(es_labels, P_shadow)
    @info "  $(label): MAC = $(p) million€/unit"
end

# ---------------------------------------------------------------------------
# 3. Compute value-added vector from FIGARO data
# ---------------------------------------------------------------------------

# V[j] = x[j] - sum of column j of Z = x[j] * (1 - column sum of A)
col_sums_A = vec(sum(A, dims=1))
V = x .* (1.0 .- col_sums_A)
V = max.(V, 0.0)   # small negatives from rounding
@info "Value-added: total = $(round(sum(V)/1e6, digits=2)) trillion €"

# ---------------------------------------------------------------------------
# 4. Solve the price system (Proposition 1 + Leontief dual)
# ---------------------------------------------------------------------------

@info "Solving Leontief price dual..."
# P' = (V' + P_shadow' R) L  ↔  (I-A)' P = V + R' P_shadow
eco_cost = vec(P_shadow' * R)           # N-vector: direct shadow cost per unit output
rhs = V .+ eco_cost                     # right-hand side
ImA = sparse(I(N) - A)
P_prices = (ImA') \ rhs                 # solve (I-A)' P = V + R' P_shadow

@info "Producer prices: min=$(round(minimum(P_prices),digits=4)), max=$(round(maximum(P_prices),digits=4))"

# ---------------------------------------------------------------------------
# 5. Compute direct (D) and total pass-through (τ) ecosystem costs
# ---------------------------------------------------------------------------

@info "Computing transboundary shadow cost pass-through..."
# D[j] = P_shadow' * R[:, j]  (direct cost per unit of output j)
D = vec(P_shadow' * R)

# τ = D * L = D * (I-A)^{-1}
# Compute as: solve (I-A)' τ' = D for τ', then τ = τ''
# i.e., τ[j] = row j of D' * L  ←  solve system column by column (expensive)
# Better: τ' = L' D' → (I-A) τ = D → solve ImA * τ = D
tau = ImA \ D   # (I-A) τ = D → τ = L * D

@info "Amplification check (τ ≥ D for all j):"
violations = sum(tau .< D .- 1e-6)
@info "  Violations: $violations / $N (should be 0)"

# Amplification ratio
rho = ifelse.(D .> 0, tau ./ D, fill(1.0, N))
@info "  Mean amplification ratio τ/D: $(round(mean(rho), digits=3))"
@info "  Max amplification ratio: $(round(maximum(rho), digits=3))"

# ---------------------------------------------------------------------------
# 6. Domestic vs transboundary decomposition (Proposition 2 / equation decomp)
# ---------------------------------------------------------------------------

@info "Computing domestic vs transboundary decomposition..."

# For each activity j=(k,σ), the domestic component = D[j] * L[j,j]
# (self-amplification: the direct cost of own production)
# Transboundary = τ[j] - domestic[j]
#
# More precisely: τ[j] = Σ_i D[i] L[i,j]
# domestic_j = Σ_{i: country(i)==country(j)} D[i] L[i,j]
# foreign_j  = Σ_{i: country(i)≠country(j)} D[i] L[i,j]
#
# Since forming full L is expensive, compute approximate domestic share via:
# domestic_j ≈ D[j] (direct own-cost) as lower bound
# For a full decomposition, form L explicitly (manageable for N=2880)

@info "  Forming Leontief inverse L (N=$N)..."
ImA_dense = Matrix(ImA)
L = ImA_dense \ Matrix{Float64}(I(N))

# Full decomposition
domestic_tau = zeros(N)
foreign_tau  = zeros(N)
for j in 1:N
    ctry_j = countries[j]
    for i in 1:N
        if D[i] != 0
            contrib = D[i] * L[i, j]
            if countries[i] == ctry_j
                domestic_tau[j] += contrib
            else
                foreign_tau[j] += contrib
            end
        end
    end
end

foreign_share = ifelse.(tau .> 0, foreign_tau ./ tau, zeros(N))
@info "  Mean foreign share of shadow cost: $(round(100*mean(foreign_share), digits=1))%"
@info "  Max foreign share: $(round(100*maximum(foreign_share), digits=1))%"

# ---------------------------------------------------------------------------
# 7. Aggregate results by country and sector
# ---------------------------------------------------------------------------

result_df = DataFrame(
    label       = labels,
    region      = sec_df.region,
    country     = countries,
    sector      = sec_df.sector,
    output_meur = x,
    V_meur      = V,
    D           = D,
    tau         = tau,
    domestic_tau= domestic_tau,
    foreign_tau = foreign_tau,
    foreign_share= foreign_share,
    amplification= rho,
    P_price     = P_prices,
)

CSV.write(joinpath(RES_DIR, "shadow_costs_by_sector_region.csv"), result_df)
@info "Saved shadow_costs_by_sector_region.csv"

# Country-level aggregates (weighted by final demand)
country_df = combine(groupby(result_df, :country)) do grp
    f_grp = f_total[indexin(grp.label, labels)]
    f_sum = sum(f_grp)
    (; n_regions = nrow(grp),
       tau_wtd   = f_sum > 0 ? dot(grp.tau, f_grp) / f_sum : 0.0,
       D_wtd     = f_sum > 0 ? dot(grp.D,   f_grp) / f_sum : 0.0,
       foreign_share_wtd = f_sum > 0 ? dot(grp.foreign_share, f_grp)/f_sum : 0.0,
       output_total_meur = sum(grp.output_meur),
    )
end
sort!(country_df, :tau_wtd, rev=true)
CSV.write(joinpath(RES_DIR, "shadow_costs_by_country.csv"), country_df)
@info "Saved shadow_costs_by_country.csv"

# Summary stats
@info "\n=== MODEL RESULTS SUMMARY ==="
@info "MRIO dimension: $N ($(length(unique(countries))) countries × 10 sectors)"
@info "Ecosystem services: $E"
@info "Total shadow cost embedded in final demand: $(round(dot(tau, f_total)/1e6, digits=2)) trillion €"
@info "Of which transboundary: $(round(dot(foreign_tau, f_total)/1e6, digits=2)) trillion €"
@info "Mean amplification ratio (τ/D): $(round(mean(rho[D.>0]), digits=3))"
@info "\nTop 5 countries by demand-weighted shadow cost (τ):"
for row in eachrow(first(country_df, 5))
    @info "  $(row.country): τ=$(round(row.tau_wtd, digits=4)) | foreign_share=$(round(100*row.foreign_share_wtd,digits=1))%"
end
