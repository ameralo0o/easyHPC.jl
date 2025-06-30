using Test
using easyHPC  # oder dein Modulname
using Random

@testset "parreduce" begin
    rng = MersenneTwister(123)
    data = rand(rng, 1_000)

    # Basic correctness: same as reduce(+)
    @test parreduce(+, data) ≈ reduce(+, data)

    # With initial value (same result)
    @test parreduce(+, data; init=0.0) ≈ reduce(+, data; init=0.0)

    # Multiplication
    small = [1, 2, 3, 4]
    @test parreduce(*, small) == 24

    # Custom init
    @test parreduce(*, small; init=2) == 48  # 2 * 1 * 2 * 3 * 4

    # Works with max
    @test parreduce(max, small) == 4

    # Works with min
    @test parreduce(min, small) == 1

    # Empty array with init works
    @test parreduce(+, Float64[]; init=5.0) == 5.0

    # Empty array without init should throw
    @test_throws ArgumentError parreduce(+, Int[])

    # Works with Bool (e.g. AND / OR)
    bools = [true, true, false, true]
    @test parreduce(|, bools) == true
    @test parreduce(&, bools) == false

    # Heterogeneous numeric types
    mix = [1, 2.0, 3]
    @test parreduce(+, mix) ≈ sum(mix)

    # Check associativity compliance (non-strict)
    @test parreduce((a, b) -> a + b, 1:1000) == sum(1:1000)

    # Very large input
    large = rand(rng, 10^6)
    @test parreduce(+, large) ≈ sum(large)

    # Custom function
    f(a, b) = a > b ? a : b  # max
    @test parreduce(f, [10, 40, 5, 99, 1]) == 99
end
