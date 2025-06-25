using BenchmarkTools
using easyHPC
using Base.Threads
using Printf
using Random




types = (Int8, Int16, Int32, Int64, Float16, Float32, Float64)
sizes = [10^6, 10^7, 10^8]

nthreads_used = Threads.nthreads()

# Header
println("-"^70)

for T in types
    for N in sizes
        println("-"^70)
        println(T)
        max_val = T <: Integer ? min(N, Int(typemax(T))) : N
        base_data = randperm(max_val) .|> T

        # Benchmark Base.sort! as baseline
        v_base = deepcopy(base_data)
        t_base = display(@benchmark sort!($v_base) setup = (GC.gc()) evals = 10 samples = 4)

        # Benchmark custom sort_numeric!
        v_custom = deepcopy(base_data)
        t_custom = display(@benchmark sort_numeric!($v_custom) setup = (GC.gc()) evals = 10 samples = 4)

    end
end
