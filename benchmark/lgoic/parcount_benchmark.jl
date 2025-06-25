using BenchmarkTools
using Random
using easyHPC


A = rand(Float64, 1024^2)

predicate = x -> x > 0.5

# Benchmarking
display(@benchmark count($predicate, $A))
display(@benchmark parcount($predicate, $A))
