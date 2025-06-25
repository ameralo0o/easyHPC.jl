using OhMyThreads

function parall(f, data; nchunks=nthreads())
    result = Threads.Atomic{Bool}(true)
    @sync for idcs in OhMyThreads.index_chunks(data; n=nchunks)
        @spawn begin
            for x in view(data, idcs)
                if !f(x)
                    result[] = false
                    break
                end
                if !result[]
                    break
                end
            end
        end
    end
    return result[]
end
