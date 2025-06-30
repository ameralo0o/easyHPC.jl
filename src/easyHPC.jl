module easyHPC

using Base.Threads



# ─────────────────────────────────────────────────────────────
# Core
include("core/parsum.jl")
include("core/parmap.jl")
include("core/parreduce.jl")

__precompile__()
include("core/parsort.jl")


export parsum, parmap, parreduce, sort_numeric!, parallel_sum_map, atomic_parallel_sum, atomic_parallel_sum2


# ─────────────────────────────────────────────────────────────
# Logic
include("logic/parlogic.jl")

export parany, parall, parcount, parmin, parmax

end
