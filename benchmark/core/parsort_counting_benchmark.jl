using BenchmarkTools
using Base.Threads
using Printf
using Random
using easyHPC
types = (Int32, Int64)
ranges = [5000, 10_000, 50_000]

nthreads_used = Threads.nthreads()


N = 10^8

for T in types

    for R in ranges
        if N < 5 * R || R > easyHPC.MAX_COUNTING_SORT_RANGE
            continue
        end
        println("-"^85)
        mn = 0
        mx = mn + R - 1
        base_data = rand(mn:mx, N) .|> T


        v1 = deepcopy(base_data)
        t1 = display(@benchmark easyHPC.sort_numeric!($v1, easyHPC.Forward()) setup = (GC.gc()) evals = 10 samples = 4)

        v2 = deepcopy(base_data)
        t2 = display(@benchmark sort!($v2) setup = (GC.gc()) evals = 10 samples = 4)

    end
end