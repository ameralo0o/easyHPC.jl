module easyHPC

using Base.Threads



# ─────────────────────────────────────────────────────────────
# Core
include("core/parsum.jl")
include("core/parmap.jl")
include("core/parreduce.jl")
include("core/parforeach.jl")
__precompile__()
include("core/parsort.jl")


export parsum, parmap, parreduce, parforeach, sort_numeric!

# ─────────────────────────────────────────────────────────────
# Math
include("math/parmean.jl")
include("math/parvar.jl")
include("math/parstd.jl")
include("math/pardot.jl")
include("math/parnorm.jl")
include("math/parexp.jl")

export parmean, parvar, parstd, pardot, parnorm, parexp

# ─────────────────────────────────────────────────────────────
# Logic
include("logic/parany.jl")
include("logic/parall.jl")
include("logic/parcount.jl")
include("logic/parmin.jl")
include("logic/parmax.jl")

export parany, parall, parcount, parmin, parmax

end
