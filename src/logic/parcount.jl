using OhMyThreads

function parcount(f, data; nchunks=nthreads())
    counts = zeros(Int, nchunks)
    @sync for (c, idcs) in enumerate(OhMyThreads.index_chunks(data; n=nchunks))
        @spawn begin
            counts[c] = count(f, view(data, idcs))
        end
    end
    return sum(counts)
end