using Test
using easyHPC
using Random

@testset "parsum" begin
    # Simple numeric ranges
    @test parsum(1:1000) == sum(1:1000)
    @test parsum(1:10) == sum(1:10)

    # Empty collections
    @test parsum(Int[]) == 0
    @test parsum(Float64[]) == 0.0

    # Singleton and small arrays
    @test parsum([1]) == 1
    @test parsum([1.0, 2.5, 3.5]) == 7.0
    @test parsum([-1, -2, -3]) == -6

    # Mixed integers and floats
    @test isapprox(parsum([1, 2.0, 3]), 6.0; atol=1e-8)

    # Large random array
    rng = MersenneTwister(1234)
    data = rand(rng, 10^6)
    @test isapprox(parsum(data), sum(data); atol=1e-8)

    # Very large numbers
    bigints = fill(10^9, 10^5)
    @test parsum(bigints) == sum(bigints)

    # Test with negative and positive floats
    data2 = [-5.5, 2.0, 3.5, -1.0]
    @test parsum(data2) == sum(data2)

    # Array with only zeros
    @test parsum(zeros(1000)) == 0.0

    # Check type stability
    @test typeof(parsum([1, 2, 3])) == Int
    @test typeof(parsum([1.0, 2.0])) == Float64

    # Nested arrays: should throw ArgumentError
    @test_throws ArgumentError parsum([[1, 2], [3, 4]])

    # Non-number elements: should throw ArgumentError
    @test_throws ArgumentError parsum(["a", "b", "c"])

    # UnitRange (non-array but iterable)
    @test parsum(3:7) == 25
end
