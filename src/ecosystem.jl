"""
Biophysical ecosystem extension.

Adds the ecosystem service coefficient matrix R (E×N) to the MRIO model,
where R[e,j] = physical volume of ES flow e per unit of gross output in sector j.

Sources: INCA Supply and Use tables, ICOS, EMEP, EFA.
"""

struct EcosystemAccounts
    R::Matrix{Float64}          # ES intensity matrix (E×N)
    K_baseline::Vector{Float64} # SEEA EA opening asset stocks (E)
    regen::Vector{Float64}      # maximum sustainable regeneration rates (E)
    es_labels::Vector{String}   # ecosystem service labels
    mac::Vector{Float64}        # marginal abatement costs (€/unit, E)
end

"""
    es_demand(ea::EcosystemAccounts, X::Vector{Float64}) -> Vector{Float64}

Total ecosystem service demand: E_demand = R * X.
"""
function es_demand(ea::EcosystemAccounts, X::Vector{Float64})
    return ea.R * X
end

"""
    es_multiplier_matrix(ea::EcosystemAccounts, L::Matrix{Float64}) -> Matrix{Float64}

Returns the ES multiplier matrix M = R * L (E×N).
M[e,j] gives total (direct + upstream) ES flow e required per unit of final demand in j.
"""
function es_multiplier_matrix(ea::EcosystemAccounts, L::Matrix{Float64})
    return ea.R * L
end

"""
    sustainability_gap(ea::EcosystemAccounts, X::Vector{Float64}) -> Vector{Float64}

Returns E_demand - regen for each ES. Positive values indicate unsustainable drawdown.
"""
function sustainability_gap(ea::EcosystemAccounts, X::Vector{Float64})
    demand = es_demand(ea, X)
    return demand .- ea.regen
end
