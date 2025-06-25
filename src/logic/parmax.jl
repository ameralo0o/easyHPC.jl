using OhMyThreads

function parmax(data; nchunks=nthreads())
    pmaxs = fill(typemax(eltype(data)), nchunks)
    @sync for (c, idcs) in enumerate(OhMyThreads.index_chunks(data; n=nchunks))
        @spawn begin
            pmaxs[c] = maximum(view(data, idcs))
        end
    end
    return maximum(pmaxs)
end

