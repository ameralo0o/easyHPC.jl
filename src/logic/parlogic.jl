# Parallel maximum
"""
    parmax(data)

Compute the maximum value in `data` using parallel reduction.

Throws an `ArgumentError` if `data` is empty.
"""
function parmax(data)
    isempty(data) && throw(ArgumentError("Cannot reduce empty collection"))
    return parreduce(max, data)
end

# Parallel minimum
"""
    parmin(data)

Compute the minimum value in `data` using parallel reduction.

Throws an `ArgumentError` if `data` is empty.
"""
function parmin(data)
    isempty(data) && throw(ArgumentError("Cannot reduce empty collection"))
    return parreduce(min, data)
end

# Parallel all - boolean array
"""
    parall(data::AbstractVector{Bool})

Check in parallel whether all elements in the boolean vector `data` are `true`.

Returns `false` as soon as the first `false` is found (early exit).
"""
function parall(data::AbstractVector{Bool}; nchunks=nthreads())
    result = Threads.Atomic{Bool}(true)

    @sync for idcs in OhMyThreads.index_chunks(data; n=nchunks)
        @spawn begin
            for x in @view data[idcs]
                !result[] && break
                if !x
                    result[] = false
                    break
                end
            end
        end
    end

    return result[]
end

# Parallel all - predicate version
"""
    parall(f, data; nchunks)

Check in parallel whether predicate `f(x)` returns `true` for all elements in `data`.

Returns `false` as soon as any element fails the predicate (early exit).

# Example

```julia
julia> iseven(x) = x % 2 == 0

julia> parall(iseven, [2, 4, 6, 8])
true

julia> parall(iseven, [2, 3, 4])
false

"""
function parall(f::Function, data; nchunks=nthreads())
    result = Threads.Atomic{Bool}(true)

    @sync for idcs in OhMyThreads.index_chunks(data; n=nchunks)
        @spawn begin
            for x in @view data[idcs]
                !result[] && break
                if !f(x)
                    result[] = false
                    break
                end
            end
        end
    end

    return result[]
end

# Parallel all - fallback
"""
    parall(data)

Fallback method for incorrect input.

Throws an `ArgumentError` if `data` is not a `Vector{Bool}`.
"""
function parall(data)
    throw(ArgumentError("Expected a Bool vector for parall(data), got $(typeof(data))"))
end

# Parallel any - boolean array
"""
    parany(data::AbstractVector{Bool})

Check in parallel whether any element in the boolean vector `data` is `true`.

Returns `true` as soon as the first `true` is found (early exit).
"""
function parany(data::AbstractVector{Bool}; nchunks=nthreads())
    result = Threads.Atomic{Bool}(false)

    @sync for idcs in OhMyThreads.index_chunks(data; n=nchunks)
        @spawn begin
            for x in @view data[idcs]
                result[] && break
                if x
                    result[] = true
                    break
                end
            end
        end
    end

    return result[]
end

# Parallel any - predicate version
"""
    parany(f, data; nchunks)

Check in parallel whether predicate `f(x)` returns `true` for any element in `data`.

Returns early as soon as a `true` value is found.

# Example

```julia
julia> isodd(x) = x % 2 == 1

julia> parany(isodd, [2, 4, 6, 8])
false

julia> parany(isodd, [2, 4, 5, 6])
true
"""
function parany(f::Function, data; nchunks=nthreads())
    result = Threads.Atomic{Bool}(false)

    @sync for idcs in OhMyThreads.index_chunks(data; n=nchunks)
        @spawn begin
            for x in @view data[idcs]
                result[] && break
                if f(x)
                    result[] = true
                    break
                end
            end
        end
    end

    return result[]
end

# Parallel any - fallback
"""
    parany(data)

Fallback method for incorrect input.

Throws an `ArgumentError` if `data` is not a `Vector{Bool}`.
"""
function parany(data)
    throw(ArgumentError("Expected a Bool vector for parany(data), got $(typeof(data))"))
end

# Parallel count
"""
    parcount(f, data; nchunks)

Count the number of elements in `data` for which the predicate `f(x)` returns `true`, using parallel reduction.

Falls back to serial counting if the input is small.

# Arguments
- `f`: A function that returns a `Bool` for each element.
- `data`: A collection of elements to be tested.

# Keyword Arguments
- `nchunks`: Number of chunks (i.e., tasks) to divide the data into. Default: number of threads.

# Returns
- `Int`: Total number of elements satisfying the predicate.

# Example

```julia
julia> iseven(x) = x % 2 == 0

julia> parcount(iseven, 1:10)
5

julia> parcount(x -> x > 100, [10, 20, 150, 300, 5])
2

"""
function parcount(f, data; nchunks=Threads.nthreads())
    # Serial fallback for small input sizes
    n = length(data)
    n < 10_000 && return count(f, data)

    # Type check only on the first element
    !isempty(data) && check_first(f, data[begin])

    # Pre-allocate counts per chunk
    counts = zeros(Int, nchunks)
    chunks = OhMyThreads.index_chunks(data; n=nchunks)

    Threads.@threads :static for i in 1:nchunks
        idcs = chunks[i]
        local cnt = 0
        @inbounds for j in idcs
            cnt += f(data[j])
        end
        counts[i] = cnt
    end
    return sum(counts)
end

# Type checking helper functions
@inline check_first(f, x) = (fx = f(x); fx isa Bool || throw_typeerr(fx))
@noinline throw_typeerr(fx) = throw(TypeError(:parcount, Bool, typeof(fx)))




