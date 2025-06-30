using easyHPC
using Test
using Random


@testset "parlogic" begin
    rng = MersenneTwister(42)

    # === Basic test data ===
    nums = 1:1000
    floats = rand(rng, 1000)
    bools_all_true = fill(true, 100)
    bools_some_false = [true, false, true, true]
    bools_all_false = fill(false, 100)

    # === parmax / parmin ===
    @test parmax(nums) == maximum(nums)
    @test parmin(nums) == minimum(nums)
    @test parmax([42]) == 42
    @test parmin([42]) == 42

    # === parall ===
    @test parall(bools_all_true) == all(bools_all_true)
    @test parall(bools_some_false) == all(bools_some_false)
    @test parall(Bool[]) == true  # same as all(Bool[])

    # === parany ===
    @test parany(bools_all_true) == any(bools_all_true)
    @test parany(bools_some_false) == any(bools_some_false)
    @test parany(bools_all_false) == any(bools_all_false)
    @test parany(Bool[]) == false  # same as any(Bool[])

    # === parcount ===
    @test parcount(isodd, nums) == count(isodd, nums)
    @test parcount(x -> x > 0.5, floats) == count(x -> x > 0.5, floats)
    @test parcount(x -> false, nums) == 0
    @test parcount(x -> true, nums) == length(nums)
    @test parcount(x -> x < 0, Int[]) == 0

    # === Edge cases ===

    # parmax / parmin on empty should error
    @test_throws ArgumentError parmax(Float64[])
    @test_throws ArgumentError parmin(Float64[])

    # parall / parany on wrong input type
    @test_throws ArgumentError parall("not a boolean array")
    @test_throws ArgumentError parany("not a boolean array")

    # parcount: invalid predicate (returns non-Bool)
    @test_throws TypeError parcount(x -> x + 1, [1, 2, 3])
end
