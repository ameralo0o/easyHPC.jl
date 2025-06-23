using BenchmarkTools
using easyHPC

A = rand(Float64, 10^8)

@btime sum($A)
@btime parsum($A)