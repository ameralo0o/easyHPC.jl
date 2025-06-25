using BenchmarkTools
using easyHPC
using Random

A = rand(Float64, 1024^2)

display(@benchmark sum($A))
display(@benchmark parsum($A))

#julia --project=. --optimize=0 --compile=min benchmark/core/parsum_benchmark.jl