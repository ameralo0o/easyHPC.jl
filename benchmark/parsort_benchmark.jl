using BenchmarkTools
using easyHPC
using Base.Threads

v1 = rand(Float64, 10^7)
v2 = deepcopy(v1)



println("Threads: ", nthreads())



println("timsort:")
@btime sort_numeric!($v1)
println(issorted(v1))
println()



println("Base.sort!:")
@btime sort!($v2)
println(issorted(v2))
println()