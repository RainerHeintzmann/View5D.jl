"""
Visualizing multiple-dimensional (ND) datasets (AbstractArrays) is important for data research and debugging of ND algorithms. `View5D.jl`  (https://github.com/RainerHeintzmann/View5D.jl) is a Java-based viewer for up to 5-dimensional data (including `Complex`). It supports three mutually linked orthogonal slicing displays for XYZ coordinates, arbitrary numbers of colors (4th `element` dimension) which can also be used to display spectral curves and a time slider for the 5th dimension.  


The Java viewer `View5D` has been integrated into julia with the help of `JavaCall.jl`.  Currently the viewer has its full Java functionality which includes displaying and interacting with 5D data. Generating up to three-dimensional histograms and interacting with them to select regions of interest in the 3D histogram but shown as a selection in the data. It allows selection of a gate `element` where thresholds can be applied to which have an effect on statistical evaluation (mean, max, min) in other `element`s if the `gate` is activated. It further supports multiplicative overlay of colors. This feature is nice when processed data (e.g. local orientation information or polarization direction or ratios) needs to be presented along with brightness data. By choosing a gray-valued and a  constant brightness value-only (HSV) colormap for brightness and orientation data respectively, in multiplicative overlay mode a result is obtained that looks like the orientation information is staining the brightness. These results look often much nicer compared to gating-based display based on a brightness-gate, which is also supported.
Color display of floating-point or 16 or higher bit data supports adaptively updating colormaps.
Zooming in on a colormap,  by changing the lower and upper display threshold, for some time the colormap is simply changed to yield a smooth experience but occasionally the cached display data is recomputed to avoid loosing fine granularity on the color levels.

`View5D` also supports displaying and interacting with tracking in 3D over time (and other combinations) datasets.  This can come in handy for single particle or cell tracking. A particularly interesting feature is that the data can be pinned (aligned) to a chosen track. 

`View5D` has 3 context menus (main panel, element view panel and general) with large range of ways to change the display. A system of equidistant location (and brightness) information (scaling and offset) is also present but not yet integrated into julia. 

The interaction to julia is currently (March 2021) at a basic level of invoking the viewer using existing data. However, it already supports a wide range of data formats: `Float32`, `Float64`, `UInt8`, `Int8`, `UInt16`, `Int16`, `UInt32`, `Int32`, `Int`.
`Complex32`, `RGB` and `Gray`

Display of `Complex`-valued data can be toggled between `magnitude`, `phase`, `real` and `imaginary` part.  A complex-valued array by default switches the viewer to a `gamma` of 0.3 easing the inspection of Fourier-transformed data. However, gamma is adjustable interactively as well as when invoking the viewer.

Since the viewer is written in Java and launched via JavaCall its thread should be pretty independent from julia. This should make the user experience pretty smooth also with minimal implications to julia threading performance. 

Current problems of `View5D` are that it is not well suited to displaying huge datasets. This is due to memory usage and the display slowing down due to on-the-fly calculations of features such as averages and the like. A further problem is that it seems very difficult to free Java memory correctly upon finalization. Even though this was not tested yet, I would expect the viewer to gradually use up memory when repeatedly invoked and closed.

Future versions will support features such as 
- retrieving user-interaction data from the viewer
- life update
- adding further elements to existing viewer(s) 

"""
module View5D
export view5d, to_jtype, viewers

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
        myviewer=activeViewer[]
    end
    jcall(myviewer, "SetGamma", Nothing, (jint, jdouble), 0, gamma);
    # SetGamma = javabridge.make_method("SetGamma","(ID)V")
end

function ProcessKeyMainWindow(key, myviewer=nothing)
    if isnothing(myviewer)
        myviewer=activeViewer[]
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
    end
    # mysize = prod(size(anArray))
    anArray = permutedims(expanddims(anArray,5),(2,1,3,4,5))
    myJArr=Array{jtype}(undef, size(anArray))
    myJArr[:].=anArray[:]
    #@show jtype
    #@show size(myJArr)
    return (myJArr,jtype)
end

viewers = Dict() # Ref[Dict]

"""
function view5d(myArray :: AbstractArray, exitingViewer=nothing, gamma=nothing)

Visualizes images and arrays via a Java-based five-dimensional viewer "View5D".
The viewer is interactive and support a wide range of user actions. 
For details see https://nanoimaging.de/View5D

`myArray`. The data to display. View5D will keep the datatyp with very few exceptions.

# Example
```julia-repl
julia> using View5D
julia> view5d(rand(5,5,5,3,5)) # a viewer with 5D data should popp up
julia> using TestImages
julia> img1 = Float32.(testimage("resolution_test_512.tif"));
julia> img2 = testimage("mandrill");
julia> img3 = testimage("simple_3d_ball.tif"); # A 3D dataset
julia> v1 = view5d(img1);
julia> v2 = view5d(img2);
julia> v3 = view5d(img3);
```
"""

function view5d(myArray :: AbstractArray, exitingViewer=nothing, gamma=nothing)
        if ! JavaCall.isloaded()
            # In the line below dirname(@__DIR__) is absolutely crucial, otherwise strange errors appear
            # in dependence of how the julia system initializes and whether you run in VScode or
            # an ordinary julia REPL. This was hinted by @mkitti
            # see https://github.com/JuliaInterop/JavaCall.jl/issues/139
            # for details
            myPath = ["-Djava.class.path=$(joinpath(dirname(@__DIR__), "jars","View5D.jar"))"]
            print("Initializing JavaCall with callpath: $myPath\n")
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
                gamma=0.3
            end
        else
            jArr = Vector{myDataType}
            myviewer=jcall(V, "Start5DViewer", V, (jArr, jint, jint, jint, jint, jint), myJArr[:], size(myJArr,1), size(myJArr,2), size(myJArr,3), size(myJArr,4),size(myJArr,5));
        end
        #@show typeof(myviewer)
        #@show myviewer
        if haskey(viewers,"active")
            if haskey(viewers,"history")
                push!(viewers["history"], viewers["active"]) 
            else
                viewers["history"]= [viewers["active"] ]
            end
        end
        viewers["active"] = myviewer
        #else
        #    activeViewer[] = myviewer # store the active viewer
        #end
        if !isnothing(gamma)
            SetGamma(gamma,myviewer)
        end
        ProcessKeys("Ti12", myviewer)   # to initialize the zoom and trigger the display update
    return myviewer
end

end # module

#=

This is a copy from my Python file to remind me of future extensions of calling this viewer.
TODO: (already in the python version)
- allow the addition of new elements into the viewer
- allow replacement of elements for live-view updates
- support axis names and scalings
- release as a general release

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
