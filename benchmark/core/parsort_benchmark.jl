using BenchmarkTools
using easyHPC
using Base.Threads
using Printf
using Random

types = (Int32, Int64)
sizes = [10^4, 10^7, 10^8, 120_000_000]

nthreads_used = Threads.nthreads()

# Header
println(@sprintf("%8s | %10s | %6s | %15s | %15s", "Type", "Size", "Threads", "sort_numeric!", "Base.sort!"))
println("-"^70)

for T in types
    for N in sizes
        max_val = T <: Integer ? min(N, Int(typemax(T))) : N
        base_data = randperm(max_val) .|> T

        # Benchmark Base.sort! as baseline
        v_base = deepcopy(base_data)
        t_base = @belapsed sort!($v_base) setup = (GC.gc()) evals = 1 samples = 4

        # Benchmark custom sort_numeric!
        v_custom = deepcopy(base_data)
        t_custom = @belapsed sort_numeric!($v_custom) setup = (GC.gc()) evals = 1 samples = 4

        @printf("%8s | %10d | %6d | %13.6f s | %13.6f s\n", string(T), N, nthreads_used, t_custom, t_base)
    end
end
