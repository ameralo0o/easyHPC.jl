using OhMyThreads

"""
    parmap(f, data; nchunks)

Apply the function `f` to each element of `data` in parallel.

Returns a new vector with the results in the original order. Internally, the data is divided into chunks to be processed by multiple threads.

# Arguments
- `f`: A function to apply to each element.
- `data`: A collection (typically a vector) of input values.

# Keyword Arguments
- `nchunks`: Number of chunks (i.e., tasks) to divide the data into. Default: number of threads.

# Returns
- `Vector`: A vector containing the result of `f(x)` for each element `x` in `data`.

# Example

```julia
julia> parmap(x -> x^2, 1:5)
5-element Vector{Int64}:
 1
 4
 9
 16
 25

"""
function parmap(f, data; nchunks=nthreads())
    T = Base.promote_op(f, eltype(data))
    result = Vector{T}(undef, length(data))
    @sync for idcs in OhMyThreads.index_chunks(data; n=nchunks)
        @spawn begin
            @inbounds for i in idcs
                result[i] = f(data[i])
            end
        end
    end
    return result
end

