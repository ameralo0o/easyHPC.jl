using BenchmarkTools
using Random
using easyHPC


A = rand(Float64, 10^7)
B = rand(Bool, 10^8)         # Bool array
ints = rand(1:1_000_000, 10^7)  # Int array
predicate = x -> begin
    s = 0.0
    for i in 1:10
        s += sin(x)^2 + cos(x)^2
    end
    s > 9.9
end

println("=== Benchmark: minimum (built-in) ===")
display(@benchmark minimum($A))

println("=== Benchmark: parmin (easyHPC) ===")
display(@benchmark parmin($A))

println("=== Benchmark: maximum (built-in) ===")
display(@benchmark maximum($A))

println("=== Benchmark: parmax (easyHPC) ===")
display(@benchmark parmax($A))

println("=== Benchmark: all (built-in, with predicate) ===")
display(@benchmark all($predicate, $A))

println("=== Benchmark: parall (with mapped predicate) ===")
display(@benchmark parall($predicate, $A))

println("=== Benchmark: any (built-in, with predicate) ===")
display(@benchmark any($predicate, $A))

println("=== Benchmark: parany (with mapped predicate) ===")
display(@benchmark parany($predicate, $A))

println("=== Benchmark: count (built-in, with predicate) ===")
display(@benchmark count($predicate, $A))

println("=== Benchmark: parcount ===")
display(@benchmark parcount($predicate, $A))