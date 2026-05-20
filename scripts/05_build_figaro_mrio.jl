"""
Script 05: Parse FIGARO-REG flat CSV → MRIO matrices (A, F, x, Z).

Input:  data/raw/figaro_reg/IOI_10SEC_D2.csv  (683MB flat MRIO)
Output: data/processed/
          figaro_A.jld2        -- technical coefficient matrix (sparse, N×N)
          figaro_F.csv         -- final demand vector (N)
          figaro_x.csv         -- gross output vector (N)
          figaro_sectors.csv   -- sector × region index

FIGARO-REG format (flat CSV, ~25M rows):
  REFREG   : origin NUTS2 region
  ROWII    : industry of origin (10 sectors + value-added rows)
  COUNTERPARTREG : destination NUTS2 region (or non-EU country code)
  COLII    : industry or final demand column of destination
  OBSVALUE : flow value (million €)

The 10 intermediate sectors:
  A     Agriculture, forestry and fishing
  B_E   Mining, manufacturing, utilities
  F     Construction
  G_I   Trade, transport, accommodation, food
  J     Information and communication
  K     Financial and insurance
  L     Real estate
  M_N   Professional, scientific, administrative support
  O_Q   Public admin, education, health
  R_U   Arts, entertainment, other services

Final demand columns: P3_S13, P3_S14, P3_S15, P51G, P5M
Value-added rows: D1, B2A3G, D29X39, CIFFOB (not used in quantity system)
"""

using CSV, DataFrames, SparseArrays, LinearAlgebra
using Pkg; Pkg.activate(joinpath(@__DIR__, ".."))

const RAW_PATH = joinpath(@__DIR__, "..", "data", "raw", "figaro_reg", "IOI_10SEC_D2.csv")
const PROC_DIR = joinpath(@__DIR__, "..", "data", "processed")
mkpath(PROC_DIR)

const SECTORS_10 = ["A", "B_E", "F", "G_I", "J", "K", "L", "M_N", "O_Q", "R_U"]
const FINAL_DEMAND = ["P3_S13", "P3_S14", "P3_S15", "P51G", "P5M"]
const VA_ROWS = ["D1", "B2A3G", "D29X39", "CIFFOB"]

# ---------------------------------------------------------------------------
# Step 1: Scan unique regions to build index
# ---------------------------------------------------------------------------

@info "Scanning unique NUTS2 regions..."
regions_set = Set{String}()
open(RAW_PATH) do f
    readline(f)  # skip header
    for line in eachline(f)
        parts = split(line, ',')
        length(parts) < 5 && continue
        push!(regions_set, parts[1])  # REFREG
        push!(regions_set, parts[3])  # COUNTERPARTREG
    end
end

# Keep only NUTS2 codes (length 4) — exclude non-EU country codes (length 2)
nuts2_regions = sort(filter(r -> length(r) == 4, collect(regions_set)))
all_regions   = sort(collect(regions_set))  # includes non-EU (for imports row)

@info "Found $(length(nuts2_regions)) NUTS2 regions and $(length(all_regions)) total regions"

# Build (region × sector) index
eu_entries  = [(r, s) for r in nuts2_regions for s in SECTORS_10]
all_entries = [(r, s) for r in all_regions   for s in SECTORS_10]

eu_idx  = Dict(e => i for (i, e) in enumerate(eu_entries))
all_idx = Dict(e => i for (i, e) in enumerate(all_entries))

N_eu  = length(eu_entries)
N_all = length(all_entries)

@info "MRIO dimension: $(N_eu) EU sector-regions (square system)"

# Save sector index
sector_df = DataFrame(
    idx    = 1:N_eu,
    region = [e[1] for e in eu_entries],
    sector = [e[2] for e in eu_entries],
)
CSV.write(joinpath(PROC_DIR, "figaro_sectors.csv"), sector_df)

# ---------------------------------------------------------------------------
# Step 2: Stream CSV → sparse Z (intermediate) and F (final demand)
# ---------------------------------------------------------------------------

@info "Building Z and F matrices (streaming 25M rows)..."
Z_I = Int[]
Z_J = Int[]
Z_V = Float64[]
F   = zeros(N_eu, length(FINAL_DEMAND))
fd_idx = Dict(f => i for (i, f) in enumerate(FINAL_DEMAND))

n_skipped = 0
open(RAW_PATH) do f
    readline(f)
    for (lnum, line) in enumerate(eachline(f))
        parts = split(line, ',')
        length(parts) < 5 && continue
        refreg, rowii, cpreg, colii, obs_str = parts[1], parts[2], parts[3], parts[4], parts[5]

        rowii in VA_ROWS && continue     # skip value-added rows
        rowii in SECTORS_10 || continue  # skip any other non-sector rows

        val = tryparse(Float64, obs_str)
        (val === nothing || val == 0.0) && continue

        row_key = (refreg, rowii)
        row_i = get(eu_idx, row_key, 0)
        row_i == 0 && (n_skipped += 1; continue)  # origin not in EU NUTS2

        if colii in SECTORS_10
            col_key = (cpreg, colii)
            col_j = get(eu_idx, col_key, 0)
            col_j == 0 && (n_skipped += 1; continue)
            push!(Z_I, row_i)
            push!(Z_J, col_j)
            push!(Z_V, val)
        elseif colii in FINAL_DEMAND
            # F[i, fd] = final demand MET BY producer (refreg, rowii)
            # row_i is already the index for (refreg, rowii)
            fd_col = fd_idx[colii]
            F[row_i, fd_col] += val
        end

        lnum % 2_000_000 == 0 && @info "  Processed $(lnum ÷ 1_000_000)M rows..."
    end
end

@info "Skipped $n_skipped rows (non-EU origins/destinations)"

Z = sparse(Z_I, Z_J, Z_V, N_eu, N_eu)
@info "Z matrix: $(size(Z)), nnz = $(nnz(Z))"

# ---------------------------------------------------------------------------
# Step 3: Compute x and A
# ---------------------------------------------------------------------------

f_total = vec(sum(F, dims=2))
x = vec(sum(Z, dims=2)) .+ f_total   # output = intermediate sales + final demand sales

# Technical coefficient matrix: A[i,j] = Z[i,j] / x[j]
x_inv = ifelse.(x .> 0, 1.0 ./ x, 0.0)
A = Z * Diagonal(x_inv)

@info "A matrix: $(size(A)), max value = $(maximum(A))"
@info "Column sums of A (should be < 1): min=$(minimum(sum(A,dims=1))), max=$(maximum(sum(A,dims=1)))"

# ---------------------------------------------------------------------------
# Step 4: Save outputs
# ---------------------------------------------------------------------------

CSV.write(joinpath(PROC_DIR, "figaro_x.csv"),
          DataFrame(idx=1:N_eu, region=[e[1] for e in eu_entries],
                    sector=[e[2] for e in eu_entries], output_meur=x))
CSV.write(joinpath(PROC_DIR, "figaro_F.csv"),
          DataFrame(hcat(sector_df[!, [:idx,:region,:sector]], DataFrame(F, FINAL_DEMAND))))

# Save A as sparse triplet (row, col, val) — full dense matrix too large at N~5000+
A_df = DataFrame(row=findnz(A)[1], col=findnz(A)[2], val=findnz(A)[3])
CSV.write(joinpath(PROC_DIR, "figaro_A_sparse.csv"), A_df)

@info "Saved figaro_x.csv, figaro_F.csv, figaro_A_sparse.csv, figaro_sectors.csv"
@info "Next: run 06_build_R_matrix.jl"
