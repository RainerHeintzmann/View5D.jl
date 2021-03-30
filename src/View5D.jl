module View5D
export view5d, to_jtype

using JavaCall
using Colors, ImageCore
# using JavaShowMethods

#View5D_jar = joinpath(@__DIR__, "View5D", "View5D.jar")
#JavaCall.addClassPath(View5D_jar)

is_complex(mat) = eltype(mat) <: Complex

expanddims(x, num_of_dims) = reshape(x, (size(x)..., ntuple(x -> 1, (num_of_dims - ndims(x)))...))

# myArray= rand(64,64,3,1,1)  # this is the 5D-Array to display
"""
    function to_jtype(something)
converts an array to 
"""
function to_jtype(anArray)
    ArrayElement = anArray[1]
    if is_complex(anArray)
        jtype=jfloat
        anArray = permutedims(expanddims(anArray,5),(2,1,3,4,5))
        #=
        mysize = size(anArray)
        fsize = prod(mysize)
        newsize = Base.setindex(mysize,mysize[5]*2,5)
        myJArr = Array{jtype}(undef, newsize)
        myJArr[1:fsize] .= real.(anArray[:]);  # copies all the real data
        myJArr[fsize+1:2*fsize] .= imag.(anArray[:]);  # copies all the imaginary data
        =#
        mysize = size(anArray)
        fsize = prod(mysize)
        newsize = Base.setindex(mysize,mysize[5]*2,5)
        myJArr = Array{jtype}(undef, newsize)
        #myJArr[:] .= reinterpret(jfloat,anArray[:]),
        myJArr[1:2:2*fsize] .= real.(anArray[:]);  # copies all the real data
        myJArr[2:2:2*fsize] .= imag.(anArray[:]);  # copies all the imaginary data
        return (myJArr, ComplexF32)
    end
    if isa(ArrayElement, RGB)
        anArray = rawview(channelview(anArray))
        anArray = collect(permutedims(expanddims(anArray,4),(2,3,4,1)))
        @show size(anArray)
    end
    if isa(ArrayElement, Gray)
        anArray = rawview(channelview(anArray))
    end
    ArrayElement = anArray[1]
    if isa(ArrayElement, Float32)
        jtype=jfloat
    elseif isa(ArrayElement, Float64)
        jtype=jdouble
    elseif isa(ArrayElement, UInt8)
        jtype=jbyte  # fake it...
        anArray = reinterpret(Int8,anArray)
    elseif isa(ArrayElement, Int8)
        jtype=jbyte
    elseif isa(ArrayElement, UInt16)
        jtype=jchar
    elseif isa(ArrayElement, Int16)
        jtype=jshort
    elseif isa(ArrayElement, UInt32)
        jtype=jlong
    elseif isa(ArrayElement, Int32)
        jtype=jlong
    elseif isa(ArrayElement, Int)
        jtype=jint
    elseif isa(ArrayElement, Int)
        jtype=jint
    end
    # mysize = prod(size(anArray))
    anArray = permutedims(expanddims(anArray,5),(2,1,3,4,5))
    myJArr=Array{jtype}(undef, size(anArray))
    myJArr[:].=anArray[:]
    @show jtype
    @show size(myJArr)
    return (myJArr,jtype)
end

function view5d(myArray::Array, exitingViewer=nothing, gamma=nothing)
        if ! JavaCall.isloaded()
            # JavaCall.init(["-Djava.class.path=$(joinpath(@__DIR__, "View5D.jl","AllClasses"))"])
            JavaCall.init(["-Djava.class.path=$(joinpath(@__DIR__, "jars","View5D.jar"))"])
            # JavaCall.init(["-Djava.class.path=$(joinpath(@__DIR__, "jars","view5d"))"])
        end
        #V = @JavaCall.jimport view5d.View5D
        V = @jimport view5d.View5D

        myJArr, myDataType=to_jtype(myArray)
        # myJArr=Array{myDataType}(undef, mysize)
        #myJArr[:].=myArray[:]
        @show size(myJArr)
        # listmethods(V,"Start5DViewer")
        if myDataType <: Complex
            jArr = Vector{jfloat}
            myviewer=jcall(V, "Start5DViewerC", V, (jArr, jint, jint, jint, jint, jint), myJArr[:], size(myArray,1), size(myArray,2), size(myArray,3), size(myArray,4),size(myArray,5));
        else
            jArr = Vector{myDataType}
            myviewer=jcall(V, "Start5DViewer", V, (jArr, jint, jint, jint, jint, jint), myJArr[:], size(myArray,1), size(myArray,2), size(myArray,3), size(myArray,4),size(myArray,5));
        end
        if !isnothing(gamma)
            myviewer=jcall(V, "Start5DViewerC", V, (jArr, jint, jint, jint, jint, jint), myJArr[:], size(myArray,1), size(myArray,2), size(myArray,3), size(myArray,4),size(myArray,5));
        return myviewer
end

#=
using JavaCall

begin
           JavaCall.init(["-Djava.class.path=$(joinpath(@__DIR__, "jars","View5D.jar"))"])
           V = @jimport view5d.View5D
           jArr = Vector{jfloat}
           myJArr = rand(jfloat, 5,5,5,5,5);
           myViewer = jcall(V, "Start5DViewerF", V, (jArr, jint, jint, jint, jint, jint), myJArr[:], 5, 5, 5, 5, 5);
end
=#

# To test:
# mv=view5d(rand(64,64,3,1,1)+im*rand(64,64,3,1,1))
#

end # module
