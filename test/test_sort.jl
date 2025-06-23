using easyHPC
using Test

v = rand(1_000)
s = parmergesort(v)
@test issorted(s)
println("parsort success")
