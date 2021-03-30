module View5D
export view5d, to_jtype

using JavaCall
using Colors, ImageCore
# using JavaShowMethods

#View5D_jar = joinpath(@__DIR__, "View5D", "View5D.jar")
#JavaCall.addClassPath(View5D_jar)

is_complex(mat) = eltype(mat) <: Complex

# expanddims(x, ::Val{N}) where N = reshape(x, (size(x)..., ntuple(x -> 1, N)...))
expanddims(x, num_of_dims) = reshape(x, (size(x)..., ntuple(x -> 1, (num_of_dims - ndims(x)))...))

function SetGamma(gamma=1.0, myviewer=nothing)
    if isnothing(myviewer)
        myviewer=activeViewer
    end
    jcall(myviewer, "SetGamma", Nothing, (jint, jdouble), 0, gamma);
    # SetGamma = javabridge.make_method("SetGamma","(ID)V")
end

function ProcessKeyMainWindow(key, myviewer=nothing)
    if isnothing(myviewer)
        myviewer=activeViewer
    end
    myviewer=jcall(myviewer, "ProcessKeyMainWindow", Nothing, (jchar,), key);
    # ProcessKeyMainWindow = javabridge.make_method("ProcessKeyMainWindow","(C)V")
end

function ProcessKeyElementWindow(key, myviewer=nothing)
    if isnothing(myviewer)
        myviewer=activeViewer
    end
    myviewer=jcall(myviewer, "ProcessElementMainWindow", Nothing, (jchar,), key);
    # ProcessKeyElementWindow = javabridge.make_method("ProcessKeyElementWindow","(C)V")
end

function UpdatePanels(myviewer=nothing)
    if isnothing(myviewer)
        myviewer=activeViewer
    end
    myviewer=jcall(myviewer, "UpdatePanels", Nothing, ());
end

function repaint(myviewer=nothing)
    if isnothing(myviewer)
        myviewer=activeViewer
    end
    myviewer=jcall(myviewer, "repaint", Nothing, ());
end

function ProcessKeys(KeyList, myviewer=nothing)
    for k in KeyList
        ProcessKeyMainWindow(k, myviewer)
        UpdatePanels(myviewer)
        repaint(myviewer)
    end
end

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
        # @show size(anArray)
    elseif isa(ArrayElement, Gray)
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
    #@show jtype
    #@show size(myJArr)
    return (myJArr,jtype)
end

activeViewer = Ref(Nothing)

"""
function view5d(myArray :: AbstractArray, exitingViewer=nothing, gamma=nothing)

Visualizes images and arrays via a Java-based five-dimensional viewer "View5D".
The viewer is interactive and support a wide range of user actions. 
For details see https://nanoimaging.de/View5D

`myArray`. The data to display. View5D will keep the datatyp with very few exceptions.
```julia-repl
julia> using View5D
julia> view5d(rand(5,5,5,3,5)) # a viewer with 5D data should popp up
julia> using TestImages
julia> img1 = Float32.(testimage("resolution_test_512.tif"));
julia> img2 = testimage("mandrill");
julia> v1 = view5d(img1);
```
"""

function view5d(myArray :: AbstractArray, exitingViewer=nothing, gamma=nothing)
        if ! JavaCall.isloaded()
            # JavaCall.init(["-Djava.class.path=$(joinpath(@__DIR__, "View5D.jl","AllClasses"))"])
            myPath = ["-Djava.class.path=$(joinpath(@__DIR__, "jars","View5D.jar"))"]
            @show myPath
            JavaCall.init(myPath)
            # JavaCall.init(["-Djava.class.path=$(joinpath(@__DIR__, "jars","view5d"))"])
        end
        #V = @JavaCall.jimport view5d.View5D
        V = @jimport view5d.View5D

        myJArr, myDataType=to_jtype(myArray)
        # myJArr=Array{myDataType}(undef, mysize)
        #myJArr[:].=myArray[:]
        # @show size(myJArr)
        # listmethods(V,"Start5DViewer")
        if myDataType <: Complex
            jArr = Vector{jfloat}
            myviewer=jcall(V, "Start5DViewerC", V, (jArr, jint, jint, jint, jint, jint), myJArr[:], size(myArray,1), size(myArray,2), size(myArray,3), size(myArray,4),size(myArray,5));
            if isnothing(gamma)
                gamma=0.2
            end
        else
            jArr = Vector{myDataType}
            myviewer=jcall(V, "Start5DViewer", V, (jArr, jint, jint, jint, jint, jint), myJArr[:], size(myJArr,1), size(myJArr,2), size(myJArr,3), size(myJArr,4),size(myJArr,5));
        end
        # activeViewer[] = myviewer # store the active viewer
        if !isnothing(gamma)
            SetGamma(gamma,myviewer)
        end
        ProcessKeys("Ti12", myviewer)   # to initialize the zoom and trigger the display update
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

#=
setSize = javabridge.make_method("setSize","(II)V")
setName = javabridge.make_method("setName","(ILjava/lang/String;)V")
NameElement = javabridge.make_method("NameElement","(ILjava/lang/String;)V")
NameWindow = javabridge.make_method("NameWindow","(Ljava/lang/String;)V")
setFontSize = javabridge.make_method("setFontSize","(I)V")
setUnit = javabridge.make_method("setUnit","(ILjava/lang/String;)V")
SetGamma = javabridge.make_method("SetGamma","(ID)V")
setMinMaxThresh = javabridge.make_method("setMinMaxThresh","(IFF)V")
ProcessKeyMainWindow = javabridge.make_method("ProcessKeyMainWindow","(C)V")
ProcessKeyElementWindow = javabridge.make_method("ProcessKeyElementWindow","(C)V")
UpdatePanels = javabridge.make_method("UpdatePanels","()V")
repaint = javabridge.make_method("repaint","()V")
hide = javabridge.make_method("hide","()V")
toFront = javabridge.make_method("toFront","()V")
SetElementsLinked = javabridge.make_method("SetElementsLinked","(Z)V") # Z means Boolean
closeAll = javabridge.make_method("closeAll","()V")
DeleteAllMarkerLists = javabridge.make_method("DeleteAllMarkerLists","()V")
ExportMarkers = javabridge.make_method("ExportMarkers","(I)[[D")
ExportMarkerLists = javabridge.make_method("ExportMarkerLists","()[[D")
ExportMarkersString = javabridge.make_method("ExportMarkers","()Ljava/lang/String;")
ImportMarkers = javabridge.make_method("ImportMarkers","([[F)V")
ImportMarkerLists = javabridge.make_method("ImportMarkerLists","([[F)V")
AddElem = javabridge.make_method("AddElement","([FIIIII)Lview5d/View5D;")
ReplaceDataB = javabridge.make_method("ReplaceDataB","(I,I[B)V")
setMinMaxThresh = javabridge.make_method("setMinMaxThresh","(IDD)V")
SetAxisScalesAndUnits = javabridge.make_method("SetAxisScalesAndUnits","(DDDDDDDDDDDDLjava/lang/String;[Ljava/lang/String;Ljava/lang/String;[Ljava/lang/String;)V")
=#
end # module
