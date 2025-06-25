using BenchmarkTools
using Random
using easyHPC

A = rand(Float64, 1024^2)
predicate = x -> x > 0.1  

display(@benchmark any($predicate, $A))
display(@benchmark parany($predicate, $A))
