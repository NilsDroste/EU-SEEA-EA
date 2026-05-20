"""
Multi-Regional Input-Output engine.

Implements the Leontief quantity system:
    X = (I - A)^{-1} F(r)

Inputs are built from FIGARO-REG tables covering 64 NACE sectors
across 240+ EU NUTS2 regions.
"""

struct MRIOModel
    A::Matrix{Float64}       # technical coefficient matrix (N×N)
    F::Vector{Float64}       # final demand vector (N)
    regions::Vector{String}  # region labels
    sectors::Vector{String}  # sector labels
end

function MRIOModel(Z::Matrix{Float64}, x::Vector{Float64},
                   F::Vector{Float64}, regions, sectors)
    n = length(x)
    A = zeros(n, n)
    for j in 1:n
        if x[j] > 0
            A[:, j] = Z[:, j] ./ x[j]
        end
    end
    return MRIOModel(A, F, collect(regions), collect(sectors))
end

"""
    leontief_inverse(m::MRIOModel) -> Matrix{Float64}

Computes L = (I - A)^{-1} via LU decomposition.
For large N, consider sparse methods or iterative solvers.
"""
function leontief_inverse(m::MRIOModel)
    n = size(m.A, 1)
    return (I - m.A) \ I(n)
end

"""
    total_output(m::MRIOModel; r=0.0) -> Vector{Float64}

Solves for gross output vector X = L * F(r).
The interest rate r scales investment-financed final demand components.
"""
function total_output(m::MRIOModel; r::Float64=0.0, investment_share::Float64=0.3,
                      phi_f::Float64=0.5)
    F_r = m.F .* (1.0 .- investment_share .* phi_f .* r)
    F_r = max.(F_r, 0.0)
    L = leontief_inverse(m)
    return L * F_r
end

"""
    footprint_matrix(m::MRIOModel) -> Matrix{Float64}

Returns the Leontief inverse L for use in footprint calculations.
"""
function footprint_matrix(m::MRIOModel)
    return leontief_inverse(m)
end
