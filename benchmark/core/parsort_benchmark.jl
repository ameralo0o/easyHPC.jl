using BenchmarkTools
using easyHPC
using Base.Threads
using Printf
using Random




sizes = [10^6, 10^7, 10^8]

nthreads_used = Threads.nthreads()

# Header
println("-"^70)


for N in sizes
    println("-"^70)

    base_data = rand(Float64, N)

    # Benchmark Base.sort! as baseline
    v_base = deepcopy(base_data)
    t_base = display(@benchmark sort($v_base))

    # Benchmark custom sort_numeric!
    v_custom = deepcopy(base_data)
    t_custom = display(@benchmark sort_numeric!($v_custom))

end

