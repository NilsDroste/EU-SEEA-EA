using Test
using LinearAlgebra
using Pkg
Pkg.activate(joinpath(@__DIR__, ".."))
include(joinpath(@__DIR__, "..", "src", "EUSEEAShadow.jl"))
using .EUSEEAShadow

# ---------------------------------------------------------------------------
# Toy economy: 2 regions × 2 sectors, 2 ecosystem services
# ---------------------------------------------------------------------------

function toy_mrio()
    # 4×4 flow matrix (2 regions × 2 sectors)
    Z = [0.1 0.05 0.02 0.01;
         0.08 0.12 0.01 0.03;
         0.03 0.01 0.15 0.06;
         0.02 0.02 0.07 0.10]
    x = [1.0, 1.2, 0.9, 1.1]
    F = x .- vec(sum(Z, dims=2))
    return MRIOModel(Z, x, F, ["R1","R2"], ["S1","S2"])
end

function toy_ecosystem(m::MRIOModel)
    N = length(m.F)
    R = [0.1 0.05 0.08 0.03;   # ES1 intensity per unit output
         0.02 0.04 0.01 0.06]  # ES2 intensity per unit output
    K_baseline = [10.0, 5.0]
    regen      = [0.5, 0.25]
    mac        = [80.0, 120.0]
    return EcosystemAccounts(R, K_baseline, regen, ["carbon", "water"], mac)
end

@testset "EUSEEAShadow" begin

    @testset "MRIO: Leontief inverse" begin
        m = toy_mrio()
        L = leontief_inverse(m)
        n = size(L, 1)
        # L should be close to (I-A)^{-1}: check (I-A)*L ≈ I
        @test (I(n) - m.A) * L ≈ I(n) atol=1e-10
        # All entries should be non-negative
        @test all(L .>= -1e-12)
    end

    @testset "MRIO: total output" begin
        m = toy_mrio()
        X = total_output(m)
        @test length(X) == length(m.F)
        @test all(X .>= 0.0)
    end

    @testset "Ecosystem: ES demand" begin
        m  = toy_mrio()
        ea = toy_ecosystem(m)
        X  = total_output(m)
        E_d = es_demand(ea, X)
        @test length(E_d) == 2
        @test all(E_d .>= 0.0)
    end

    @testset "Ecosystem: sustainability gap" begin
        m  = toy_mrio()
        ea = toy_ecosystem(m)
        X  = total_output(m)
        gap = sustainability_gap(ea, X)
        @test length(gap) == 2
    end

    @testset "SFC: asset stock dynamics" begin
        s = AssetStock([10.0, 5.0])
        # With zero demand, stock should grow toward carrying capacity
        K_series = simulate_stock_dynamics(s, zeros(2, 10))
        @test size(K_series) == (2, 11)
        @test all(K_series .>= 0.0)
        # Stocks should not exceed carrying capacity
        @test all(K_series .<= s.K_max .+ 1e-10)
    end

    @testset "SFC: ecological risk premium" begin
        s = AssetStock([10.0, 5.0])
        s.K .= [8.0, 4.0]   # 20% depletion
        Δr = ecological_risk_premium(s; phi=0.02)
        @test Δr ≈ 0.02 * 0.20 atol=1e-10
    end

    @testset "Shadow prices: price dual solution" begin
        m  = toy_mrio()
        ea = toy_ecosystem(m)
        N  = length(m.F)
        V  = total_output(m) .* 0.4
        result = solve_shadow_prices(ea, m, V)
        @test length(result.P_shadow) == 2
        @test length(result.P) == N
        @test size(result.passthrough) == (1, N)
        # Shadow prices should equal MACs (by construction)
        @test result.P_shadow ≈ ea.mac
        # All prices should be positive
        @test all(result.P .>= 0.0)
    end

    @testset "Shadow prices: pass-through" begin
        m  = toy_mrio()
        ea = toy_ecosystem(m)
        V  = total_output(m) .* 0.4
        result = solve_shadow_prices(ea, m, V)
        w = ones(length(m.F))
        pt = price_passthrough(result, w)
        @test pt >= 0.0
    end

end
