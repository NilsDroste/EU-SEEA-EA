"""
Stock-Flow Consistent (SFC) asset dynamics.

Tracks ecosystem asset stocks over time and feeds ecological degradation
back into the macroeconomic interest rate (the LM channel).

K_dot(t) = G(K) - E_demand(t)

where G(K) is a logistic regeneration function with carrying capacity K_max.
"""

mutable struct AssetStock
    K::Vector{Float64}       # current asset stock levels (E)
    K_baseline::Vector{Float64}
    K_max::Vector{Float64}   # ecological carrying capacities (E)
    r_nat::Vector{Float64}   # intrinsic regeneration rates (E)
end

function AssetStock(K_baseline::Vector{Float64}; K_max_multiplier::Float64=1.2,
                    r_nat::Vector{Float64}=fill(0.05, length(K_baseline)))
    return AssetStock(copy(K_baseline), copy(K_baseline),
                      K_baseline .* K_max_multiplier, r_nat)
end

"""
    regeneration(s::AssetStock) -> Vector{Float64}

Logistic regeneration: G(K) = r_nat * K * (1 - K/K_max).
"""
function regeneration(s::AssetStock)
    return s.r_nat .* s.K .* (1.0 .- s.K ./ s.K_max)
end

"""
    step!(s::AssetStock, E_demand::Vector{Float64}; dt::Float64=1.0)

Advances asset stocks by one period under given ecosystem service demand.
"""
function step!(s::AssetStock, E_demand::Vector{Float64}; dt::Float64=1.0)
    G = regeneration(s)
    s.K .= max.(s.K .+ dt .* (G .- E_demand), 0.0)
    return s.K
end

"""
    simulate_stock_dynamics(s::AssetStock, E_demand_series::Matrix{Float64};
                            dt=1.0) -> Matrix{Float64}

Simulates stock dynamics over T periods. E_demand_series is (E×T).
Returns K_series (E×T+1), where the first column is the initial stock.
"""
function simulate_stock_dynamics(s::AssetStock, E_demand_series::Matrix{Float64};
                                 dt::Float64=1.0)
    E, T = size(E_demand_series)
    K_series = zeros(E, T + 1)
    K_series[:, 1] = s.K
    for t in 1:T
        step!(s, E_demand_series[:, t]; dt=dt)
        K_series[:, t+1] = s.K
    end
    return K_series
end

"""
    ecological_risk_premium(s::AssetStock; phi::Float64=0.02) -> Float64

Computes the interest rate markup from ecosystem degradation:
    Δr = phi * mean(max(0, (K_baseline - K) / K_baseline))
"""
function ecological_risk_premium(s::AssetStock; phi::Float64=0.02)
    depletion = max.(0.0, (s.K_baseline .- s.K) ./ s.K_baseline)
    return phi * mean(depletion)
end
