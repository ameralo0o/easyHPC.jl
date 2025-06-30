using BenchmarkTools
using easyHPC
using Random


data = rand(10^7)

f(x) = sqrt(x) * sin(x)

println("=== Benchmark: map ===")
display(@benchmark map($f, $data) )

println("=== Benchmark: parmap ===")
display(@benchmark parmap($f, $data))