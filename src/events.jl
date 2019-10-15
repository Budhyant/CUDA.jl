# Events for timing

export CuEvent, record, synchronize, elapsed, @elapsed


"""
    CuEvent()

Create a new CUDA event.
"""
mutable struct CuEvent
    handle::CUevent
    ctx::CuContext

    function CuEvent(flags=EVENT_DEFAULT)
        handle_ref = Ref{CUevent}()
        @apicall(:cuEventCreate, (Ptr{CUevent}, Cuint), handle_ref, flags)

        ctx = CuCurrentContext()
        obj = new(handle_ref[], ctx)
        finalizer(unsafe_destroy!, obj)
        return obj
    end
end

function unsafe_destroy!(e::CuEvent)
    if isvalid(e.ctx)
        @apicall(:cuEventDestroy, (CUevent,), e)
    end
end

Base.unsafe_convert(::Type{CUevent}, e::CuEvent) = e.handle

Base.:(==)(a::CuEvent, b::CuEvent) = a.handle == b.handle
Base.hash(e::CuEvent, h::UInt) = hash(e.handle, h)

"""
    record(e::CuEvent, stream=CuDefaultStream())

Record an event on a stream.
"""
record(e::CuEvent, stream::CuStream=CuDefaultStream()) =
    @apicall(:cuEventRecord, (CUevent, CUstream), e, stream)

"""
    synchronize(e::CuEvent)

Waits for an event to complete.
"""
synchronize(e::CuEvent) = @apicall(:cuEventSynchronize, (CUevent,), e)

"""
    wait(e::CuEvent, stream=CuDefaultStream())

Make a stream wait on a event. This only makes the stream wait, and not the host; use
[`synchronize(::CuEvent)`](@ref) for that.
"""
wait(e::CuEvent, stream::CuStream=CuDefaultStream()) =
    @apicall(:cuStreamWaitEvent, (CUstream, CUevent, Cuint), stream, e, 0)

"""
    elapsed(start::CuEvent, stop::CuEvent)

Computes the elapsed time between two events (in seconds).
"""
function elapsed(start::CuEvent, stop::CuEvent)
    time_ref = Ref{Cfloat}()
    @apicall(:cuEventElapsedTime, (Ptr{Cfloat}, CUevent, CUevent),
                                  time_ref, start, stop)
    return time_ref[]/1000
end

"""
    @elapsed stream ex
    @elapsed ex

A macro to evaluate an expression, discarding the resulting value, instead returning the
number of seconds it took to execute on the GPU, as a floating-point number.
"""
macro elapsed(stream, ex)
    quote
        t0, t1 = CuEvent(), CuEvent()
        record(t0, $(esc(stream)))
        $(esc(ex))
        record(t1, $(esc(stream)))
        synchronize(t1)
        elapsed(t0, t1)
    end
end
macro elapsed(ex)
    quote
        @elapsed(CuDefaultStream(), $(esc(ex)))
    end
end
