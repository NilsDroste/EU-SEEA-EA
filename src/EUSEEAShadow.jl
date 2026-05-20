module EUSEEAShadow

using LinearAlgebra
using SparseArrays
using Statistics

include("mrio.jl")
include("ecosystem.jl")
include("sfc.jl")
include("shadow_price.jl")

export
    # mrio.jl
    MRIOModel, leontief_inverse, total_output, footprint_matrix,
    # ecosystem.jl
    EcosystemAccounts, es_demand, es_multiplier_matrix,
    # sfc.jl
    AssetStock, simulate_stock_dynamics, ecological_risk_premium,
    # shadow_price.jl
    ShadowPriceResult, solve_shadow_prices, price_passthrough

end
