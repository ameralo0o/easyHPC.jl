using Test
using Random
using easyHPC

@testset "sort_numeric!" begin
    # --- Simple cases ---
    @testset "Simple ints" begin
        @test sort_numeric!([2, 1]) == [1, 2]
        @test sort_numeric!([100, -50]) == [-50, 100]
    end

    @testset "Floats" begin
        @test sort_numeric!([1.5, 2.0, -3.0]) == [-3.0, 1.5, 2.0]
        @test sort_numeric!([π, 2.0, 1.0]) == [1.0, 2.0, π]
    end

    @testset "Descending order" begin
        v = [10, 20, 15]
        sort_numeric!(v, easyHPC.Reverse())
        @test v == [20, 15, 10]
    end

    @testset "Already sorted" begin
        v = [1, 2, 3, 4, 5]
        sort_numeric!(v)
        @test v == [1, 2, 3, 4, 5]
    end

    @testset "Reverse sorted" begin
        v = [5, 4, 3, 2, 1]
        sort_numeric!(v)
        @test v == [1, 2, 3, 4, 5]
    end

    @testset "Edge cases" begin
        @test sort_numeric!(Int[]) == Int[]
        @test sort_numeric!([42]) == [42]
        @test sort_numeric!([7, 7, 7]) == [7, 7, 7]
    end

    @testset "Negative values" begin
        v = [-5, -1, -100]
        sort_numeric!(v)
        @test v == [-100, -5, -1]
    end

    @testset "With duplicates" begin
        v = [1, 3, 2, 2, 3, 1]
        sort_numeric!(v)
        @test v == [1, 1, 2, 2, 3, 3]
    end

    @testset "Booleans" begin
        v = [true, false, true]
        sort_numeric!(v)
        @test v == [false, true, true]
    end

    # --- Random + large sets ---
    @testset "Large input" begin
        v = shuffle(1:10_000)
        sort_numeric!(v)
        @test v == collect(1:10_000)
    end

    @testset "Large reverse" begin
        v = shuffle(1:5000)
        sort_numeric!(v, easyHPC.Reverse())
        @test v == reverse(1:5000)
    end

    # --- Small integer ranges ---
    @testset "Small value range" begin
        v = rand(1:5, 100)
        sort_numeric!(v)
        @test issorted(v)
    end

    @testset "Negative to positive range" begin
        v = rand(-50:50, 200)
        sort_numeric!(v)
        @test issorted(v)
    end

    # --- Special types ---
    @testset "BigInt support" begin
        v = BigInt[10, 100, 1, -50]
        sort_numeric!(v)
        @test v == BigInt[-50, 1, 10, 100]
    end

    @testset "Float with zeros" begin
        v = [-0.0, 0.0, 1.0, -1.0]
        sort_numeric!(v)
        @test v == [-1.0, -0.0, 0.0, 1.0]
    end

    @testset "Mixed Float range" begin
        v = randn(1000)
        sort_numeric!(v)
        @test issorted(v)
    end

    # --- Many small sets to force insertion sort ---
    for i in 1:10
        @testset "Insertion sort case $i" begin
            v = rand(1:100, rand(5:20))
            sort_numeric!(v)
            @test issorted(v)
        end
    end

    # --- Miscellaneous cases ---
    @testset "Int8 vector" begin
        v = Int8[3, -1, 2]
        sort_numeric!(v)
        @test v == Int8[-1, 2, 3]
    end

    @testset "MaxInt edge" begin
        v = [typemax(Int) - 2, typemax(Int), typemax(Int) - 1]
        sort_numeric!(v)
        @test issorted(v)
    end

    @testset "MinInt edge" begin
        v = [typemin(Int), -1, 0]
        sort_numeric!(v)
        @test issorted(v)
    end

    @testset "Tiny float differences" begin
        v = [1.00000001, 1.00000000, 1.00000002]
        sort_numeric!(v)
        @test issorted(v)
    end

    @testset "All identical floats" begin
        v = fill(3.14, 100)
        sort_numeric!(v)
        @test v == fill(3.14, 100)
    end

    @testset "Sorted descending already" begin
        v = [5, 4, 3, 2, 1]
        sort_numeric!(v, easyHPC.Reverse())
        @test v == [5, 4, 3, 2, 1]
    end

    @testset "Sort subset" begin
        v = [5, 99, 1, 100]
        sort_numeric!(v[2:3])  # in-place view
        @test v[2:3] == [1, 99] || v[2:3] == [99, 1]  # not guaranteed
    end

    @testset "Large identical values" begin
        v = fill(123, 10_000)
        sort_numeric!(v)
        @test v == fill(123, 10_000)
    end

    @testset "Empty float array" begin
        v = Float64[]
        sort_numeric!(v)
        @test v == Float64[]
    end
end
