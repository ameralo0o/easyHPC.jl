"""
    parreduce(f, data; nchunks, init)

Reduce `data` in parallel using binary function `f`.

If `init` is given, it is used as the initial value.
"""
function parreduce(f, data; nchunks=nthreads(), init=nothing)
    isempty(data) && init === nothing &&
        throw(ArgumentError("Cannot reduce empty collection without `init`"))

    chunks = OhMyThreads.index_chunks(data; n=nchunks)
    T = init === nothing ? eltype(data) : typeof(init)
    partials = Vector{T}(undef, nchunks)
    has_result = falses(nchunks)

    @sync for (c, idcs) in enumerate(chunks)
        @spawn begin
            part = view(data, idcs)
            if isempty(part)
                has_result[c] = false
            else
                partials[c] = init === nothing ? reduce(f, part) : reduce(f, part; init=init)
                has_result[c] = true
            end
        end
    end

    # Combine partials that are valid
    result_set = false
    acc = init

    for (i, valid) in enumerate(has_result)
        if valid
            if result_set
                acc = f(acc, partials[i])
            else
                acc = partials[i]
                result_set = true
            end
        end
    end

    return acc
end
