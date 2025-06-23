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

const PARALLEL_THRESHOLD = 100_000  # Min length for parallel sort
const SMALL_THRESHOLD = 32          # Max length for insertion sort
const MAX_COUNTING_SORT_RANGE = 10^4  # Max value range for counting sort
const MAX_PARALLEL_DEPTH = floor(Int, log2(Threads.nthreads()))  # Depth limit for nested threading

"""
    sort_numeric!(v::Vector{T}, o::Ordering=Forward())

Efficiently sorts a numeric vector `v` in-place.
Automatically chooses the best algorithm based on type and size.

- `Forward()` for ascending (default)
- `Reverse()` for descending

The function uses:
- Insertion sort for small vectors
- Counting or radix sort for integer vectors with small range
- Multithreaded merge or quicksort for large data
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
        parallel_merge_sort!(v, o)
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

        # Choose pivot via median-of-three
        mid = div(lo + hi, 2)
        pivot = median_of_three(v[lo], v[mid], v[hi], o)

        # Partition the array
        p = hoare_partition!(v, lo, hi, pivot, o)

        # Recursive calls with optional threading
        if (hi - lo > PARALLEL_THRESHOLD) && depth < MAX_PARALLEL_DEPTH
            t = Threads.@spawn quicksort!(v, lo, p, o, depth + 1)
            quicksort!(v, p + 1, hi, o, depth + 1)
            wait(t)
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
    return v
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
    parallel_merge_sort!(v::AbstractVector{T}, o::Ordering=Forward(), depth::Int=0)

Parallel merge sort implementation using threads.
Recursively sorts left and right halves in parallel if large enough.
Falls back to insertion sort for small vectors.
"""
function parallel_merge_sort!(v::AbstractVector{T}, o::Ordering=Forward(), depth::Int=0) where {T<:Real}
    n = length(v)
    if n <= SMALL_THRESHOLD
        insertion_sort!(v, o)
        return v
    end

    mid = div(n, 2)
    left = view(v, 1:mid)
    right = view(v, mid+1:n)

    if n > PARALLEL_THRESHOLD
        t = Threads.@spawn parallel_merge_sort!(left, o, depth + 1)
        parallel_merge_sort!(right, o, depth + 1)
        wait(t)
    else
        parallel_merge_sort!(left, o, depth + 1)
        parallel_merge_sort!(right, o, depth + 1)
    end

    merge_sorted!(v, left, right, o)
    return v
end

"""
    merge_sorted!(dest, left, right, o::Ordering)

Merges two sorted subarrays `left` and `right` into `dest` in order `o`.
"""
function merge_sorted!(dest::AbstractVector{T}, left::AbstractVector{T}, right::AbstractVector{T}, o::Ordering) where {T}
    i = j = k = 1
    nl, nr = length(left), length(right)
    tmp = similar(dest, nl + nr)

    while i <= nl && j <= nr
        if isless(o, left[i], right[j])
            tmp[k] = left[i]
            i += 1
        else
            tmp[k] = right[j]
            j += 1
        end
        k += 1
    end

    while i <= nl
        tmp[k] = left[i]
        i += 1
        k += 1
    end

    while j <= nr
        tmp[k] = right[j]
        j += 1
        k += 1
    end

    dest .= tmp
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
    nt = Threads.nthreads()

    # 1. Count per thread
    local_counts = [zeros(Int, valrange) for _ in 1:nt]
    Threads.@threads for t in 1:nt
        tid = Threads.threadid()
        chunk = cld(n, nt)
        lo = (tid - 1) * chunk + 1
        hi = min(tid * chunk, n)
        for i in lo:hi
            bin = Int(v[i]) - Int(mn) + 1
            local_counts[tid][bin] += 1
        end
    end

    # 2. Merge counts into global
    global_counts = zeros(Int, valrange)
    for t in 1:nt
        global_counts .+= local_counts[t]
    end
    @assert sum(global_counts) == n

    # 3. Compute global start positions (exclusive prefix sum)
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

    # 4. Compute per-thread bin start offsets
    thread_offsets = [zeros(Int, valrange) for _ in 1:nt]
    for bin in 1:valrange
        pos = global_offsets[bin]
        for t in 1:nt
            thread_offsets[t][bin] = pos
            pos += local_counts[t][bin]
        end
    end

    # 5. Distribute elements in output array
    output = similar(v)
    Threads.@threads for t in 1:nt
        tid = Threads.threadid()
        chunk = cld(n, nt)
        lo = (tid - 1) * chunk + 1
        hi = min(tid * chunk, n)

        local_pos = thread_offsets[tid]
        for i in lo:hi
            val = v[i]
            bin = Int(val) - Int(mn) + 1
            idx = local_pos[bin] + 1
            @inbounds output[idx] = val
            local_pos[bin] += 1
        end
    end

    v .= output
    return v
end
