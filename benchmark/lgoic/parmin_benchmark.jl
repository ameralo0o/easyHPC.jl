using BenchmarkTools
using easyHPC
using Random

A = rand(Float64, 1024^2)

display(@benchmark minimum($A))
display(@benchmark parmin($A))

