using BenchmarkTools
using easyHPC
using Random
using SpecialFunctions

data = rand(10^8)
f(x) = log(abs(sin(x^2) + cos(x^3))) + exp(-x) * erf(x)

println("=== Benchmark: reduce ===")
display(@benchmark reduce(/, map($f, $data)))

println("=== Benchmark: parreduce ===")
display(@benchmark parreduce(/, parmap($f, $data)))


println("-"^85)
println("-"^85)

data2 = rand(10^8)
f1(x) = sqrt(x) * sin(x)

println("=== Benchmark: reduce ===")
display(@benchmark reduce(/, map($f, $data2)))

println("=== Benchmark: parreduce ===")
display(@benchmark parreduce(/, map($f, $data2)))