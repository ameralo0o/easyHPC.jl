using Test
using easyHPC  # replace with the actual module name if different
using Random

@testset "parmap" begin
    rng = MersenneTwister(42)
    data = rand(rng, 1000)

    # Basic equivalence to map
    @test parmap(x -> x^2, data) ≈ map(x -> x^2, data)

    # Identity
    @test parmap(identity, data) == data

    # Different return types
    @test parmap(string, 1:10) == map(string, 1:10)
    @test parmap(x -> x % 2 == 0, 1:10) == map(x -> x % 2 == 0, 1:10)
    @test parmap(x -> (x, x^2), 1:5) == map(x -> (x, x^2), 1:5)

    # Empty input
    @test parmap(x -> x + 1, Int[]) == Int[]
    @test parmap(string, String[]) == String[]

    # Custom struct mapping
    struct Foo
        x::Int
    end
    foos = [Foo(i) for i in 1:10]
    @test parmap(f -> f.x + 1, foos) == map(f -> f.x + 1, foos)

    # Large input
    big = rand(rng, 10^5)
    @test parmap(sin, big) ≈ map(sin, big)

    # Non-inferrable / boxed result (Any output)
    hetero = 1:5
    @test parmap(x -> x % 2 == 0 ? x : string(x), hetero) == map(x -> x % 2 == 0 ? x : string(x), hetero)

    # Thread safety test: check if side effects are isolated (should not be used this way, but test it)
    global_counter = Threads.Atomic{Int}(0)
    result = parmap(x -> (Threads.atomic_add!(global_counter, 1); x + 1), 1:100)
    @test result == collect(2:101)
    @test global_counter[] == 100

    # Error propagation: function that throws
    @test_throws CompositeException parmap(x -> sqrt(x), [-1.0, 0.0, 1.0])
end
