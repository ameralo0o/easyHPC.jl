using BenchmarkTools
using easyHPC
using Random

A = rand(Float64, 1024^2)

display(@benchmark maximum($A))
display(@benchmark parmax($A))

