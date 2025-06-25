using OhMyThreads
function parsum(data; nchunks=nthreads())
    psums = zeros(eltype(data), nchunks)
    @sync for (c, idcs) in enumerate(OhMyThreads.index_chunks(data; n=nchunks))
        @spawn begin
            psums[c] = sum(view(data, idcs))
        end
    end
    return sum(psums)
end