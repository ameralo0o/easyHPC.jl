using BenchmarkTools
using easyHPC
using Random


A = rand(10^9);
#println("=== Benchmark: sum ===")
display(@benchmark sum($A))

println("=== Benchmark: parsum ===")
display(@benchmark parsum($A))


println("=== Benchmark: parallel_sum_map ===")
display(@benchmark parallel_sum_map($A))



println("=== Benchmark: atomic_parallel_sum ===")
display(@benchmark atomic_parallel_sum($A))



println("=== Benchmark: atomic_parallel_sum2 ===")
display(@benchmark atomic_parallel_sum2($A))
