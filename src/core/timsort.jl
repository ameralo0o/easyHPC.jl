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
"""
isless(::Forward, a, b) = a < b
isless(::Reverse, a, b) = a > b


# === Main Sorting Function ===

const SMALL_THRESHOLD = 32  # Below this threshold, use insertion sort
const MAX_COUNTING_SORT_RANGE = 10^4  # Max allowed value range for counting sort

"""
    sort_numeric!(v::Vector{T}, o::Ordering=Forward())

Efficiently sorts a numeric vector `v` in-place.
Automatically chooses the best algorithm based on type and size.

- `Forward()` for ascending (default)
- `Reverse()` for descending
"""
function sort_numeric!(v::Vector{T}, o::Ordering=Forward()) where {T<:Real}
    n = length(v)

    # Early return if already sorted
    if issorted_custom(v, o)
        return v
        # Reverse if in reverse order
    elseif issorted_custom(v, reverse_ordering(o))
        reverse!(v)
        return v
    end

    # Use insertion sort for small arrays
    if n <= SMALL_THRESHOLD
        insertion_sort!(v, o)
        return v
    end

    # Integer-specific optimizations
    if T <: Integer
        mn, mx = extrema(v)

        if mx >= mn
            diff = mx - mn

            # Use counting sort if range is small
            if diff >= 0 && diff <= MAX_COUNTING_SORT_RANGE
                range = diff + 1
                if n >= 5 * range
                    counting_sort!(v, mn, mx, o)
                    return v
                end
            end

            # Use radix sort if range fits in few bits
            if bits_required(mn, mx) <= 24
                radix_sort!(v, o, mn, mx)
                return v
            end
        end
    end

    # Fallback: quicksort
    quicksort!(v, 1, n, o)
end


# === Helper Functions ===

"""
    reverse_ordering(o::Ordering)

Returns the opposite of the current ordering.
"""
function reverse_ordering(o::Ordering)
    o isa Forward && return Reverse()
    o isa Reverse && return Forward()
end

"""
    issorted_custom(v::Vector, o::Ordering)

Checks if the vector is already sorted in the given order.
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
    v
end


# === Counting Sort ===

"""
    counting_sort!(v::Vector{Int}, mn::Int, mx::Int, o::Ordering)

Efficient counting sort for small-range integers.
"""
function counting_sort!(v::Vector{Int}, mn::Int, mx::Int, o::Ordering)
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


# === Radix Sort ===

"""
    radix_sort!(v::Vector{T}, o::Ordering, mn::T, mx::T) where {T<:Integer}

Efficient radix sort for integers with small bit-widths.
"""
function radix_sort!(v::Vector{T}, o::Ordering, mn::T, mx::T) where {T<:Integer}
    shift_v = v .- mn
    maxval = maximum(shift_v)
    tmp = similar(v)

    base = 256  # 8-bit digits
    passes = 0

    while (maxval >> (8 * passes)) > 0
        radix_pass!(shift_v, tmp, base, 8 * passes, o)
        shift_v, tmp = tmp, shift_v
        passes += 1
    end

    v .= shift_v .+ mn
    return v
end

"""
    radix_pass!(src::Vector{T}, dst::Vector{T}, base::Int, shift::Int, o::Ordering)

Performs one radix sort pass on the current digit (byte).
"""
function radix_pass!(src::Vector{T}, dst::Vector{T}, base::Int, shift::Int, o::Ordering) where {T<:Integer}
    n = length(src)
    counts = zeros(Int, base)

    for i in 1:n
        digit = (src[i] >> shift) & (base - 1)
        counts[digit+1] += 1
    end

    if o isa Forward
        for i in 2:base
            counts[i] += counts[i-1]
        end
    else
        for i in base-1:-1:1
            counts[i] += counts[i+1]
        end
    end

    for i in n:-1:1
        digit = (src[i] >> shift) & (base - 1)
        counts[digit+1] -= 1
        dst[counts[digit+1]+1] = src[i]
    end
end


# === Quicksort ===

"""
    quicksort!(v::Vector, lo::Int, hi::Int, o::Ordering)

Generic in-place quicksort implementation.
"""
function quicksort!(v, lo, hi, o::Ordering)
    while lo < hi
        pivot = v[div(lo + hi, 2)]
        i, j = lo, hi
        while i <= j
            while isless(o, v[i], pivot)
                i += 1
            end
            while isless(o, pivot, v[j])
                j -= 1
            end
            if i <= j
                v[i], v[j] = v[j], v[i]
                i += 1
                j -= 1
            end
        end

        if j - lo < hi - i
            quicksort!(v, lo, j, o)
            lo = i
        else
            quicksort!(v, i, hi, o)
            hi = j
        end
    end
    v
end


# === Bit Width Calculation ===

"""
    bits_required(min_val::Integer, max_val::Integer)

Returns the number of bits needed to represent the range between min and max.
"""
function bits_required(min_val::Integer, max_val::Integer)
    diff = max_val - min_val
    return sizeof(typeof(diff)) * 8 - leading_zeros(diff)
end
