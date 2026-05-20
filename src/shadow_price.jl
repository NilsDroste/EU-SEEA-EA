"""
Dual shadow price solver.

Solves the Leontief price dual:
    P' = P'A + V' + P_shadow' * R

Rearranging:
    P' = (V' + P_shadow' * R) * L

where L = (I-A)^{-1} and P_shadow is identified as the marginal abatement cost vector.

The pass-through term P_shadow' * R * L gives the supply-chain-embedded
ecosystem cost per unit of final demand in each sector-region.
"""

struct ShadowPriceResult
    P_shadow::Vector{Float64}   # ES shadow prices (€/unit, E)
    P::Vector{Float64}          # adjusted producer prices (N)
    passthrough::Matrix{Float64} # P_shadow' * R * L  (1×N, as row)
    P_shadow_label::Vector{String}
end

"""
    solve_shadow_prices(ea::EcosystemAccounts, m::MRIOModel,
                        V::Vector{Float64}) -> ShadowPriceResult

Solves for the full price system given:
- ea.mac  as the shadow price vector (MACs = P_shadow)
- V       as the conventional value-added vector
- m.A     as the technical coefficient matrix
"""
function solve_shadow_prices(ea::EcosystemAccounts, m::MRIOModel,
                              V::Vector{Float64})
    L = leontief_inverse(m)
    P_shadow = ea.mac

    # (V' + P_shadow' R) * L
    eco_cost = P_shadow' * ea.R   # 1×N
    P = L' * (V .+ vec(eco_cost))

    passthrough = P_shadow' * ea.R * L   # 1×N

    return ShadowPriceResult(P_shadow, P, passthrough, ea.es_labels)
end

"""
    price_passthrough(result::ShadowPriceResult,
                      demand_weights::Vector{Float64}) -> Float64

Computes the demand-weighted average ecosystem shadow cost
per unit of final expenditure.
"""
function price_passthrough(result::ShadowPriceResult,
                            demand_weights::Vector{Float64})
    w = demand_weights ./ sum(demand_weights)
    return dot(vec(result.passthrough), w)
end
