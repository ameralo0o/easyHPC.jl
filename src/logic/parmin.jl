using OhMyThreads

function parmin(data; nchunks=nthreads())
    pmins = fill(typemax(eltype(data)), nchunks)
    @sync for (c, idcs) in enumerate(OhMyThreads.index_chunks(data; n=nchunks))
        @spawn begin
            pmins[c] = minimum(view(data, idcs))
        end
    end
    return minimum(pmins)
end

