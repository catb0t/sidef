
#
## Array methods
#

function call(h::Type{Sidef_Types_Array_Array}, v::Any...)
    Sidef_Types_Array_Array(Any[v...])
end

function getindex(a::Sidef_Types_Array_Array, i::Sidef_Types_Number_Number)
    (a.value)[i.value+1]
end

function setindex!(a::Sidef_Types_Array_Array, v::Any, i::Sidef_Types_Number_Number)
    #setindex!(a.value, v, i.value)
    (a.value)[i.value+1] = v
end

function is_empty(a::Sidef_Types_Array_Array)
    length(a.value) == 0
end

function len(a::Sidef_Types_Array_Array)
    Sidef_Types_Number_Number(length(a.value))
end

function ft(a::Sidef_Types_Array_Array, from::Sidef_Types_Number_Number, to::Sidef_Types_Number_Number)
    Sidef_Types_Array_Array((a.value)[from.value+1:to.value+1])
end

function ft(a::Sidef_Types_Array_Array, from::Sidef_Types_Number_Number)
    Sidef_Types_Array_Array((a.value)[from.value+1:length(a.value)])
end

function each(a::Sidef_Types_Array_Array, block::Sidef_Types_Block_Block)
    for item in a.value
        block(item)
    end
end

function map(a::Sidef_Types_Array_Array, block::Sidef_Types_Block_Block)
    arr = Any[]
    for item in a.value
        push!(arr, block(item))
    end
    Sidef_Types_Array_Array(arr)
end

function grep(a::Sidef_Types_Array_Array, block::Sidef_Types_Block_Block)
    arr = Any[]
    for item in a.value
        block(item) && push!(arr, item)
    end
    Sidef_Types_Array_Array(arr)
end

function join(a::Sidef_Types_Array_Array)
    str = ""
    for item in a.value
        str *= string(item)
    end
    Sidef_Types_String_String(str)
end

function join(a::Sidef_Types_Array_Array, sep::Sidef_Types_String_String)
    str = ""
    a = a.value
    sep = sep.value
    for i in 1:length(a)-1
        str *= string(a[i]) * sep
    end
    str *= string(a[end])
    Sidef_Types_String_String(str)
end
