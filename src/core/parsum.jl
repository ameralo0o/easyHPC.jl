# Parallel sum
"""
parsum(data)

Compute the sum of all elements in `data` in parallel.

# Example
parsum(1:1_000_000)
"""
function parsum(data)
    eltype(data) <: Number || throw(ArgumentError("parsum expects a collection of Numbers"))
    parreduce(+, data; init=zero(eltype(data)))
end


function parallel_sum_map(data; nchunks=nthreads())
    psums = zeros(eltype(data), nchunks)
    @sync for (c, idcs) in enumerate(OhMyThreads.index_chunks(data; n=nchunks))
        @spawn begin
            psums[c] = sum(view(data, idcs))
        end
    end
    return sum(psums)
end


function atomic_parallel_sum(data; nchunks=Threads.nthreads())
    acc = Threads.Atomic{eltype(data)}(zero(eltype(data)))
    @sync for idcs in OhMyThreads.index_chunks(data; n=nchunks)
        @spawn Threads.atomic_add!(acc, sum(@view data[idcs]))
    end
    return acc[]
end





function atomic_parallel_sum2(data; threshold=300_000 * Threads.nthreads())
    n = length(data)
    nchunks = ceil(Int, n / threshold)
    partials = Vector{eltype(data)}(undef, nchunks)
    ranges = OhMyThreads.index_chunks(data; n=nchunks)
    for (i, idcs) in enumerate(ranges)
        partials[i] = atomic_parallel_sum(@view(data[idcs]))
    end
    return sum(partials)
end
