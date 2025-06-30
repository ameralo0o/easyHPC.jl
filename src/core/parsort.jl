using OhMyThreads
using DataStructures: PriorityQueue
using FLoops


# === Ordering Definition ===

"""
    abstract type Ordering

Abstract type used to define sort order.
Use `Forward()` for ascending or `Reverse()` for descending order.
"""
abstract type Ordering end

"""
    struct Forward <: Ordering

Represents ascending sort order (default).
"""
struct Forward <: Ordering end

"""
    struct Reverse <: Ordering

Represents descending sort order.
"""
struct Reverse <: Ordering end

"""
    isless(ordering, a, b)

Comparison function depending on the ordering direction.
- Returns `a < b` for `Forward()`
- Returns `a > b` for `Reverse()`
"""
isless(::Forward, a, b) = a < b
isless(::Reverse, a, b) = a > b


# === Main Sorting Function ===

const PARALLEL_THRESHOLD = 1^4  # Min length for parallel sort
const SMALL_THRESHOLD = 32          # Max length for insertion sort
const MAX_COUNTING_SORT_RANGE = 10^4  # Max value range for counting sort


function max_parallel_depth()
    return max(1, floor(Int, log2(Threads.nthreads())))
end


"""
    sort_numeric!(v::Vector{T}, o::Ordering=Forward()) where T <: Real

Efficiently sorts a numeric vector `v` in-place using the most suitable algorithm based on the data type, size, and value distribution.

Supports custom ordering via:
- `Forward()` for ascending order (default)
- `Reverse()` for descending order

# Behavior
The algorithm selection is adaptive:
- Uses **insertion sort** for small vectors (length ≤ SMALL_THRESHOLD)
- Uses **counting sort** (or parallel counting sort) for integer vectors with small value ranges
- Falls back to **quicksort** or optionally **parallel merge sort** for large general cases

Automatically handles already sorted or reverse-sorted inputs efficiently.

# Arguments
- `v`: A vector of numeric values to be sorted in-place.
- `o`: An `Ordering` (optional), either `Forward()` or `Reverse()`.

# Returns
- The sorted vector `v` (modified in-place).

# Example

```julia
julia> v = [5, 1, 9, 3, 7];

julia> sort_numeric!(v)
5-element Vector{Int64}:
 1
 3
 5
 7
 9

julia> sort_numeric!(v, Reverse())
5-element Vector{Int64}:
 9
 7
 5
 3
 1

"""
function sort_numeric!(v::Vector{T}, o::Ordering=Forward()) where {T<:Real}
    n = length(v)

    # Return early if already sorted
    if issorted_custom(v, o)
        return v
    elseif issorted_custom(v, reverse_ordering(o))
        reverse!(v)
        return v
    end

    # Use insertion sort for small arrays
    if n <= SMALL_THRESHOLD
        insertion_sort!(v, o)
        return v
    end

    # Integer-specific fast paths
    if T <: Integer
        mn, mx = extrema(v)

        if mx >= mn
            diff = mx - mn
            range = diff + 1

            # Counting sort if small value range
            if n >= 5 * range
                if n >= 1_000_000
                    parallel_counting_sort!(v, mn, mx, o)
                else
                    counting_sort!(v, mn, mx, o)
                end
                return v
            end
        end
    end

    # Fallback to quicksort or merge sort
    if n > PARALLEL_THRESHOLD
        #parallel_merge_sort!(v, o)
        quicksort!(v, 1, n, o, 0)
    else
        quicksort!(v, 1, n, o, 0)
    end
    return v
end


# === Helper Functions ===

"""
    reverse_ordering(o::Ordering)

Returns the opposite of the current ordering.
- `Forward()` becomes `Reverse()`
- `Reverse()` becomes `Forward()`
"""
function reverse_ordering(o::Ordering)
    o isa Forward && return Reverse()
    o isa Reverse && return Forward()
end

"""
    issorted_custom(v::Vector, o::Ordering)

Checks if the vector is already sorted in the given order.
Returns `true` if sorted, otherwise `false`.
"""
function issorted_custom(v, o::Ordering)
    for i in 2:length(v)
        if isless(o, v[i], v[i-1])
            return false
        end
    end
    return true
end


# === Insertion Sort ===

"""
    insertion_sort!(v::Vector, o::Ordering)

Simple in-place insertion sort for small arrays.
Stable and adaptive to nearly-sorted data.
"""
function insertion_sort!(v, o::Ordering)
    for i in 2:length(v)
        x = v[i]
        j = i - 1
        while j >= 1 && isless(o, x, v[j])
            v[j+1] = v[j]
            j -= 1
        end
        v[j+1] = x
    end
    return v
end


# === Counting Sort ===

"""
    counting_sort!(v::Vector{Int}, mn::Int, mx::Int, o::Ordering)

Efficient counting sort for small-range integers.
Sorts in O(n + k) time where k = mx - mn.

Arguments:
- `v`: vector of integers to sort
- `mn`, `mx`: known minimum and maximum of values
- `o`: ordering direction

Throws an error if range is invalid or too large.
"""
function counting_sort!(v::Vector{T}, mn::T, mx::T, o::Ordering) where {T<:Integer}
    diff = mx - mn
    range = diff + 1

    if diff < 0 || range > MAX_COUNTING_SORT_RANGE || range <= 0
        error("counting_sort! invalid range: $range (mn=$mn, mx=$mx)")
    end

    counts = zeros(Int, range)
    offset = 1 - mn

    for x in v
        counts[x+offset] += 1
    end

    idx = 1
    if o isa Forward
        for i in 1:range
            cnt = counts[i]
            for _ in 1:cnt
                v[idx] = i - offset
                idx += 1
            end
        end
    else
        for i in range:-1:1
            cnt = counts[i]
            for _ in 1:cnt
                v[idx] = i - offset
                idx += 1
            end
        end
    end

    return v
end

"""
    radix_pass!(src::Vector{T}, dst::Vector{T}, base::Int, shift::Int, o::Ordering)

Performs one radix sort pass on the current digit (byte).

- `src`: source array with shifted values
- `dst`: destination array to write output
- `base`: digit base (e.g., 256)
- `shift`: bit shift for current digit
- `o`: sort ordering
"""
function radix_pass!(src::Vector{T}, dst::Vector{T}, base::Int, shift::Int, o::Ordering) where {T<:Integer}
    n = length(src)
    counts = zeros(Int, base)

    # Count digit occurrences
    for i in 1:n
        digit = (src[i] >> shift) & (base - 1)
        counts[digit+1] += 1
    end

    # Compute digit start positions
    if o isa Forward
        for i in 2:base
            counts[i] += counts[i-1]
        end
    else
        for i in base-1:-1:1
            counts[i] += counts[i+1]
        end
    end

    # Place elements in output array
    for i in n:-1:1
        digit = (src[i] >> shift) & (base - 1)
        counts[digit+1] -= 1
        dst[counts[digit+1]+1] = src[i]
    end
end


# === Quicksort ===

"""
    quicksort!(v::Vector, lo::Int, hi::Int, o::Ordering, depth::Int=0)

Generic in-place quicksort implementation with optional parallelism.
- Switches to insertion sort for small ranges.
- Uses Hoare partition scheme.
- Median-of-three pivot selection.
- Supports parallel recursive calls depending on depth and range.
"""
function quicksort!(v::Vector, lo::Int, hi::Int, o::Ordering, depth::Int=0)
    while lo < hi
        if hi - lo + 1 <= SMALL_THRESHOLD
            insertion_sort!(view(v, lo:hi), o)
            return
        end

        mid = div(lo + hi, 2)
        pivot = median_of_three(v[lo], v[mid], v[hi], o)
        p = hoare_partition!(v, lo, hi, pivot, o)


        if hi - lo > PARALLEL_THRESHOLD && depth < max_parallel_depth()
            @sync begin
                OhMyThreads.@spawn quicksort!(v, lo, p, o, depth + 1)
                OhMyThreads.@spawn quicksort!(v, p + 1, hi, o, depth + 1)
            end
            return
        else

            if p - lo < hi - (p + 1)
                quicksort!(v, lo, p, o, depth + 1)
                lo = p + 1
            else
                quicksort!(v, p + 1, hi, o, depth + 1)
                hi = p
            end
        end
    end
end


function quicksort_serial!(v::Vector, lo::Int, hi::Int, o::Ordering)
    while lo < hi
        if hi - lo + 1 <= SMALL_THRESHOLD
            insertion_sort!(view(v, lo:hi), o)
            return
        end

        mid = div(lo + hi, 2)
        pivot = median_of_three(v[lo], v[mid], v[hi], o)
        p = hoare_partition!(v, lo, hi, pivot, o)

        if p - lo < hi - (p + 1)
            quicksort_serial!(v, lo, p, o)
            lo = p + 1
        else
            quicksort_serial!(v, p + 1, hi, o)
            hi = p
        end
    end
end



# === Quicksort Partitioning Helpers ===

"""
    hoare_partition!(v::Vector, lo::Int, hi::Int, pivot, o::Ordering)

Hoare's partition scheme used by quicksort.
Partitions `v[lo:hi]` around the `pivot` value according to the given ordering.
Returns the partition index.
"""
function hoare_partition!(v::Vector, lo::Int, hi::Int, pivot, o::Ordering)
    i = lo - 1
    j = hi + 1

    while true
        begin
            i += 1
        end
        while isless(o, v[i], pivot)
            i += 1
        end

        begin
            j -= 1
        end
        while isless(o, pivot, v[j])
            j -= 1
        end

        if i >= j
            return j
        end

        v[i], v[j] = v[j], v[i]
    end
end

"""
    median_of_three(a, b, c, o::Ordering)

Returns the median of the three input values `a`, `b`, `c` according to ordering `o`.
Used to select a good pivot value for quicksort.
"""
function median_of_three(a, b, c, o::Ordering)
    if isless(o, a, b)
        if isless(o, b, c)
            return b
        elseif isless(o, a, c)
            return c
        else
            return a
        end
    else
        if isless(o, a, c)
            return a
        elseif isless(o, b, c)
            return c
        else
            return b
        end
    end
end


# === Bit Width Calculation ===

"""
    bits_required(min_val::Integer, max_val::Integer)

Returns the number of bits required to represent all integers between `min_val` and `max_val`.
Useful for deciding if radix sort is appropriate.
"""
function bits_required(min_val::Integer, max_val::Integer)
    diff = max_val - min_val
    return sizeof(typeof(diff)) * 8 - leading_zeros(diff)
end


# === Parallel Merge Sort ===
"""
    parallel_merge_sort!(v::Vector{T}, o::Ordering=Forward())

Parallel merge sort using shared pre-allocated temp buffer.
"""
function parallel_merge_sort!(v::AbstractVector{T}, o::Ordering=Forward(), depth::Int=0, tmp::AbstractVector{T}=similar(v)) where {T<:Real}
    n = length(v)

    if n <= SMALL_THRESHOLD
        insertion_sort!(v, o)
        return v
    end

    mid = div(n, 2)
    left = view(v, 1:mid)
    right = view(v, mid+1:n)
    tmpleft = view(tmp, 1:mid)
    tmpright = view(tmp, mid+1:n)

    if depth < max_parallel_depth()
        @sync begin
            OhMyThreads.@spawn parallel_merge_sort!(left, o, depth + 1, tmpleft)
            OhMyThreads.@spawn parallel_merge_sort!(right, o, depth + 1, tmpright)
        end
    else
        parallel_merge_sort!(left, o, depth + 1, tmpleft)
        parallel_merge_sort!(right, o, depth + 1, tmpright)
    end

    merge_sorted!(v, left, right, o, tmp)
    return v
end

"""
    merge_sorted!(dest, left, right, o, tmp)

Merges `left` and `right` into `dest` using `tmp` as temporary buffer.
Requires that `tmp` has at least length(dest).
"""
function merge_sorted!(
    dest::AbstractVector{T},
    left::AbstractVector{T},
    right::AbstractVector{T},
    o::Ordering,
    tmp::AbstractVector{T}
) where {T}
    i = j = k = 1
    nl, nr = length(left), length(right)

    @inbounds while i <= nl && j <= nr
        if isless(o, left[i], right[j])
            tmp[k] = left[i]
            i += 1
        else
            tmp[k] = right[j]
            j += 1
        end
        k += 1
    end

    @inbounds while i <= nl
        tmp[k] = left[i]
        i += 1
        k += 1
    end

    @inbounds while j <= nr
        tmp[k] = right[j]
        j += 1
        k += 1
    end

    @inbounds dest .= tmp
    return dest
end




# === Parallel Counting Sort ===

"""
    parallel_counting_sort!(v::Vector{Int}, mn::Int, mx::Int, o::Ordering)

Parallelized version of counting sort for integer vectors.
Splits input over threads and combines local histograms.
"""
function parallel_counting_sort!(v::Vector{T}, mn::T, mx::T, o::Ordering) where {T<:Integer}
    n = length(v)
    valrange = Int(mx - mn + 1)

    if valrange > easyHPC.MAX_COUNTING_SORT_RANGE
        error("Value range $valrange exceeds allowed counting sort range")
    end

    nthreads = Threads.nthreads()

    # Step 1: Allocate thread-local histograms as a 2D array
    # local_counts[bin, thread] holds frequency count for each bin per thread
    local_counts = zeros(Int, valrange, nthreads)

    # Step 2: Divide work into chunks per thread and count values
    chunks = OhMyThreads.index_chunks(v; n=nthreads)
    Threads.@threads for tid in 1:nthreads
        chunk = chunks[tid]
        counts = @view local_counts[:, tid]
        for idx in chunk
            bin = Int(v[idx]) - Int(mn) + 1
            @inbounds counts[bin] += 1
        end
    end

    # Step 3: Merge thread-local counts into global histogram
    global_counts = sum(local_counts, dims=2)
    global_counts = vec(global_counts)

    @assert sum(global_counts) == n

    # Step 4: Compute global prefix sum (offsets)
    global_offsets = zeros(Int, valrange + 1)
    if o isa Forward
        for i in 1:valrange
            global_offsets[i+1] = global_offsets[i] + global_counts[i]
        end
    else
        for i in valrange:-1:1
            global_offsets[i] = global_offsets[i+1] + global_counts[i]
        end
    end

    # Step 5: Compute thread-local write offsets from global_offsets
    thread_offsets = [zeros(Int, valrange) for _ in 1:nthreads]
    for bin in 1:valrange
        pos = global_offsets[bin]
        for t in 1:nthreads
            thread_offsets[t][bin] = pos
            pos += local_counts[bin, t]
        end
    end

    # Step 6: Parallel write to output array (disjoint per thread)
    output = similar(v)
    Threads.@threads for tid in 1:nthreads
        chunk = chunks[tid]
        offsets = thread_offsets[tid]
        for idx in chunk
            val = v[idx]
            bin = Int(val) - Int(mn) + 1
            outidx = offsets[bin] + 1
            @inbounds output[outidx] = val
            offsets[bin] += 1
        end
    end

    # Step 7: Copy output back in parallel
    Threads.@threads for i in eachindex(v)
        v[i] = output[i]
    end

    return v
end
