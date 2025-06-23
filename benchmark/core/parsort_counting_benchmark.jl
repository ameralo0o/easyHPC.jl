using BenchmarkTools
using Base.Threads
using Printf
using Random
using easyHPC
types = (Int32, Int64)
sizes = [10^6, 10^7, 10^8]
ranges = [100, 500, 1000, 5000, 10000]

nthreads_used = Threads.nthreads()

println(@sprintf("%8s | %10s | %6s | %8s | %15s | %15s", "Type", "Size", "Range", "Threads", "sort_numeric!", "Base.sort!"))
println("-"^85)

for T in types
    for N in sizes
        for R in ranges
            if N < 5 * R || R > easyHPC.MAX_COUNTING_SORT_RANGE
                continue
            end

            mn = 0
            mx = mn + R - 1
            base_data = rand(mn:mx, N) .|> T


            v1 = deepcopy(base_data)
            t1 = @belapsed easyHPC.sort_numeric!($v1, easyHPC.Forward()) setup = (GC.gc()) evals = 1 samples = 4

            v2 = deepcopy(base_data)
            t2 = @belapsed sort!($v2) setup = (GC.gc()) evals = 1 samples = 4

            @printf("%8s | %10d | %6d | %8d | %13.6f s | %13.6f s\n", string(T), N, R, nthreads_used, t1, t2)
        end
    end
end
