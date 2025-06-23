using Base.Threads

function parallel_radixsort!(x::Vector{U}) where {U <: Union{Int32,Int64,UInt32,UInt64,Float32,Float64}}
    n = length(x)
    num_threads = nthreads()
    chunk_size = cld(n, num_threads)
    
    # Histogramme für jeden Thread
    histograms = [zeros(UInt32, 256) for _ in 1:num_threads]
    output = similar(x)
    
    passes = sizeof(U)
    mask = UInt8(0xff)
    
    @inbounds for pass in 0:passes-1
        shift = pass * 8
        
        # Phase 1: Lokale Histogramme parallel berechnen
        @threads for tid in 1:num_threads
            start_idx = (tid-1)*chunk_size + 1
            end_idx = min(tid*chunk_size, n)
            hist = histograms[tid]
            fill!(hist, 0)
            
            # SIMD-fähige Schleife (automatische Vektorisierung)
            for i in start_idx:end_idx
                byte = UInt8((reinterpret(UInt64, x[i]) >> shift) & mask) + 1
                hist[byte] += 1
            end
        end
        
        # Phase 2: Globale Histogramme kombinieren
        global_hist = zeros(UInt32, 256)
        for tid in 1:num_threads
            for i in 1:256
                global_hist[i] += histograms[tid][i]
            end
        end
        
        # Präfixsumme berechnen
        total = UInt32(0)
        for i in 1:256
            count = global_hist[i]
            global_hist[i] = total
            total += count
        end
        
        # Phase 3: Elemente platzieren (parallel)
        @threads for tid in 1:num_threads
            start_idx = (tid-1)*chunk_size + 1
            end_idx = min(tid*chunk_size, n)
            local_hist = copy(global_hist)
            
            # Add previous thread contributions
            for i in 1:256
                for prev_tid in 1:(tid-1)
                    local_hist[i] += histograms[prev_tid][i]
                end
            end
            
            # Elemente in Ausgabearray einfügen
            for i in start_idx:end_idx
                val = x[i]
                byte = UInt8((reinterpret(UInt64, val) >> shift) & mask) + 1
                pos = local_hist[byte] += 1
                output[pos] = val
            end
        end
        
        # Arrays tauschen für nächsten Durchgang
        x, output = output, x
    end
    
    # Bei ungerader Passanzahl Ergebnis zurückkopieren
    if isodd(passes)
        copyto!(output, x)
        return output
    end
    return x
end

# Spezialbehandlung für vorzeichenbehaftete Integer
function parallel_radixsort!(x::Vector{T}) where {T <: Signed}
    n = length(x)
    min_val = typemin(T)
    y = Vector{UInt64}(undef, n)
    
    @inbounds for i in 1:n
        y[i] = reinterpret(UInt64, x[i] ⊻ min_val)
    end
    
    result = parallel_radixsort!(y)
    
    @inbounds for i in 1:n
        x[i] = reinterpret(T, result[i]) ⊻ min_val
    end
    return x
end

# Spezialbehandlung für Floats
function parallel_radixsort!(x::Vector{T}) where {T <: AbstractFloat}
    n = length(x)
    y = Vector{UInt64}(undef, n)
    
    @inbounds for i in 1:n
        f = x[i]
        if f >= 0
            y[i] = reinterpret(UInt64, f)
        else
            y[i] = ~reinterpret(UInt64, -f)
        end
    end
    
    result = parallel_radixsort!(y)
    
    @inbounds for i in 1:n
        u = result[i]
        if u & (UInt64(1) << 63) == 0  # positives Vorzeichen
            x[i] = reinterpret(T, u)
        else
            x[i] = -reinterpret(T, ~u)
        end
    end
    return x
end