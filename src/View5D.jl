"""
Visualizing multiple-dimensional (ND) datasets (AbstractArrays) is important for data research and debugging of ND algorithms. `View5D.jl`  (https://github.com/RainerHeintzmann/View5D.jl) is a Java-based viewer for up to 5-dimensional data (including `Complex`). It supports three mutually linked orthogonal slicing displays for XYZ coordinates, arbitrary numbers of colors (4th `element` dimension) which can also be used to display spectral curves and a time slider for the 5th dimension.  


The Java viewer `View5D` (https://nanoimaging.de/View5D) has been integrated into julia with the help of `JavaCall.jl`.  Currently the viewer has its full Java functionality which includes displaying and interacting with 5D data. Generating up to three-dimensional histograms and interacting with them to select regions of interest in the 3D histogram but shown as a selection in the data. It allows selection of a gate `element` where thresholds can be applied to which have an effect on statistical evaluation (mean, max, min) in other `element`s if the `gate` is activated. It further supports multiplicative overlay of colors. This feature is nice when processed data (e.g. local orientation information or polarization direction or ratios) needs to be presented along with brightness data. By choosing a gray-valued and a  constant brightness value-only (HSV) colormap for brightness and orientation data respectively, in multiplicative overlay mode a result is obtained that looks like the orientation information is staining the brightness. These results look often much nicer compared to gating-based display based on a brightness-gate, which is also supported.
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
export view5d
export process_key_element_window, process_key_main_window, process_keys
export set_axis_scales_and_units
export repaint, update_panels, to_front, hide_viewer
export set_gamma, set_element_name, get_num_elements, get_num_times
export set_display_size

using JavaCall
using Colors, ImageCore
# using JavaShowMethods

#View5D_jar = joinpath(@__DIR__, "View5D", "View5D.jar")
#JavaCall.addClassPath(View5D_jar)

is_complex(mat) = eltype(mat) <: Complex

# expanddims(x, ::Val{N}) where N = reshape(x, (size(x)..., ntuple(x -> 1, N)...))
expanddims(x, num_of_dims) = reshape(x, (size(x)..., ntuple(x -> 1, (num_of_dims - ndims(x)))...))

"""
    set_gamma(gamma=1.0, myviewer=nothing; element=0)
    modifies the display gamma in myviewer
gamma: defines how the data is displayed via shown_value = data .^gamma. 
        More precisely: clip((data.-low).(high-low)) .^ gamma
myviewer: The viewer to which this gamma should be applied to. By default the active viewer is used.
element: to which color channel (element) should this gamma be applied to

#Example
```julia
julia> v2 = view5d(rand(Float64,6,5,4,3,1))
julia> set_gamma(0.2,element=1)
```
"""
function set_gamma(gamma=1.0, myviewer=nothing; element=0)
    myviewer=get_viewer(myviewer)
    jcall(myviewer, "SetGamma", Nothing, (jint, jdouble), element, gamma);
    update_panels()
end

"""
    set_element_name(new_name, myviewer=nothing; element=0)
    provides a new name to the `element` displayed in the viewer
myviewer: The viewer to apply this to. By default the active viewer is used.
element: The element to rename
"""
function set_element_name(new_name::String, myviewer=nothing; element=0)
    myviewer=get_viewer(myviewer)
    jcall(myviewer, "setName", Nothing, (jint, JString), element, new_name);
    update_panels()
end

"""
    set_display_size(sx::Int,sy::Int, myviewer=nothing)
    sets the size on the screen, the viewer is occupying
sx: horizontal size in pixels
sy: vertical size in pixels
myviewer: The viewer to apply this to. By default the active viewer is used.
"""
function set_display_size(sx::Int,sy::Int, myviewer=nothing) # ; reinit=true
    myviewer=get_viewer(myviewer)
    myviewer=jcall(myviewer, "setSize", Nothing, (jint,jint),sx,sy) ;
    #if reinit
    #    process_keys("i", myviewer)  # does not work, -> panel?
    #end
end

"""
    get_num_elements(myviewer=nothing)
    gets the number of currently existing elements in the viewer
myviewer: The viewer to apply this to. By default the active viewer is used.
"""
function get_num_elements(myviewer=nothing)
    myviewer=get_viewer(myviewer)
    num_elem=jcall(myviewer, "getNumElements", jint, ());
end

function set_axis_scales_and_units(myviewer=nothing;element=0, mytime=0)
    myviewer=get_viewer(myviewer)
    jcall(myviewer, "getNuSetAxisScalesAndUnitsmElements", Nothing, (jdouble,jdouble,jdouble,jdoublejdouble,jdouble,jdouble,jdoublejdouble,jdouble,jdouble,jdouble,
            JString,JString[],JString,JString[]),
            );

end

"""
    get_num_time(myviewer=nothing)
    gets the number of currently existing time points in the viewer
myviewer: The viewer to apply this to. By default the active viewer is used.
"""
function get_num_times(myviewer=nothing)
    myviewer=get_viewer(myviewer)
    num_elem=jcall(myviewer, "getNumTime", jint, ());
end

"""
    to_front(myviewer=nothing)
    moves the viewer on top of other windows
myviewer: The viewer to apply this to. By default the active viewer is used.
"""
function to_front(myviewer=nothing)
    myviewer=get_viewer(myviewer)
    jcall(myviewer, "toFront", Nothing, ());
end

"""
    hide(myviewer=nothing)
    hides the viewer. It can be shown again by calling "to_front"
myviewer: The viewer to apply this to. By default the active viewer is used.
"""
function hide_viewer(myviewer=nothing)
    myviewer=get_viewer(myviewer)
    jcall(myviewer, "hide", Nothing, ());
end

function update_panels(myviewer=nothing)
    myviewer=get_viewer(myviewer)
    myviewer=jcall(myviewer, "UpdatePanels", Nothing, ());
end

function repaint(myviewer=nothing)
    myviewer=get_viewer(myviewer)
    myviewer=jcall(myviewer, "repaint", Nothing, ());
end

function process_key_main_window(key::Char, myviewer=nothing)
    myviewer=get_viewer(myviewer)
    myviewer=jcall(myviewer, "ProcessKeyMainWindow", Nothing, (jchar,), key);
    # ProcessKeyMainWindow = javabridge.make_method("ProcessKeyMainWindow","(C)V")
end

"""
    process_key_element_window(key::Char, myviewer=nothing)
    Processes a single key in the element window (bottom right panel of "view5d").
    For a discription of keys look at the context menu in the viewer. 
    More information at https://nanoimaging.de/View5D
key: single key to process inthe element window
"""
function process_key_element_window(key::Char, myviewer=nothing)
    myviewer=get_viewer(myviewer)
    myviewer=jcall(myviewer, "ProcessKeyElementWindow", Nothing, (jchar,), key);
    # ProcessKeyElementWindow = javabridge.make_method("ProcessKeyElementWindow","(C)V")
end


"""
    process_keys(KeyList::String, myviewer=nothing; mode="main")
    Sends key strokes to the viewer. This allows an easy remote-control of the viewer since almost all of its features can be controlled by key-strokes.
    Note that panel-specific keys (e.g."q": switching to plot-diplay) are currently not supported.
    For a discription of keys look at the context menu in the viewer. 
    More information at https://nanoimaging.de/View5D

KeyList: list of keystrokes (as a String) to successively be processed by the viewer. An update is automatically called afterwards.

myviewer: the viewer to which the keys are send.

mode: determines to which panel the keys are sent to. Currently supported: "main" (default) or "element"

#see also
process_key_main_window: processes a single key in the main window
process_key_element_window: processes a single key in the element window
"""
function process_keys(KeyList::String, myviewer=nothing; mode="main")
    for k in KeyList
        if mode=="main"
            process_key_main_window(k, myviewer)
        elseif mode=="element"
            process_key_element_window(k, myviewer)
        else
            throw(ArgumentError("unsupported mode $mode. Use `main` or `element`"))
        end
        update_panels(myviewer)
        repaint(myviewer)
    end
    return
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
        # anArray = permutedims(expanddims(anArray,5),(2,1,3,4,5)) # expanddims(anArray,5) # 
        anArray = expanddims(anArray,5) # 
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
        newsize = Base.setindex(mysize,mysize[1]*2,1)
        myJArr = Array{jtype}(undef, newsize)
        #myJArr[:] .= reinterpret(jfloat,anArray[:]),
        myJArr[1:2:2*fsize] .= real.(anArray[:]);  # copies all the real data
        myJArr[2:2:2*fsize] .= imag.(anArray[:]);  # copies all the imaginary data
        return (myJArr, ComplexF32)
    end
    if isa(ArrayElement, RGB)
        anArray = rawview(channelview(anArray))
        # anArray = collect(permutedims(expanddims(anArray,5),(3,2,4,1,5)))
        anArray = collect(permutedims(expanddims(anArray,5),(2,3,4,1,5)))
        # @show size(anArray)
    elseif isa(ArrayElement, Gray)
        # anArray = rawview(channelview(permutedims(expanddims(anArray,5),(2,1,3,4,5))))        
        anArray = expanddims(rawview(channelview(anArray)),5)
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
    anArray = expanddims(anArray,5) # permutedims(expanddims(anArray,5),(2,1,3,4,5))  # 
    myJArr=Array{jtype}(undef, size(anArray))
    myJArr[:] .= anArray[:]
    #@show jtype
    #@show size(myJArr)
    return (myJArr,jtype)
end

viewers = Dict() # Ref[Dict]

function get_active_viewer()
    if haskey(viewers,"active")
        myviewer=viewers["active"]    
    else
        myviewer=nothing
    end
end

function set_active_viewer(myviewer)
    if haskey(viewers,"active")
        if haskey(viewers,"history")
            push!(viewers["history"], viewers["active"]) 
        else
            viewers["history"]= [viewers["active"] ]
        end
    end
    viewers["active"] = myviewer
end

function get_viewer(viewer=nothing)
    if isnothing(viewer)
        return get_active_viewer()
    else
        return viewer
    end
end

function start_viewer(viewer, myJArr, jtype="jfloat", mode="new", isCpx=false; element=0, mytime=0)
    jArr = Vector{jtype}
    #@show size(myJArr)
    sizeX,sizeY,sizeZ,sizeE,sizeT = size(myJArr)
    addCpx = ""
    if isCpx
        sizeX /= 2
        addCpx = "C"
    end

    V = @jimport view5d.View5D
    if isnothing(viewer)
        viewer = get_active_viewer();
        if isnothing(viewer)
            viewer=V
        end
    end

    if mode == "new"
        command = string("Start5DViewer", addCpx)
        myviewer=jcall(V, command, V, (jArr, jint, jint, jint, jint, jint),
                        myJArr[:], sizeX, sizeY, sizeZ, sizeE, sizeT);            
    elseif mode == "replace"
        command = string("ReplaceData", addCpx)
        #@show viewer 
        jcall(viewer, command, Nothing, (jint, jint, jArr), element, mytime, myJArr[:]);
        myviewer = viewer
    elseif mode == "add_element"
        command = string("AddElement", addCpx)
        myviewer=jcall(viewer, command, V, (jArr, jint, jint, jint, jint, jint),
                        myJArr[:],sizeX, sizeY, sizeZ, sizeE, sizeT);
    else
        throw(ArgumentError("unknown mode $mode, choose new, replace or add_element"))
    end
end

"""
    view5d(data :: AbstractArray, viewer=nothing; gamma=nothing, mode="new", element=0, time=0)

Visualizes images and arrays via a Java-based five-dimensional viewer "View5D".
The viewer is interactive and support a wide range of user actions. 
For details see https://nanoimaging.de/View5D

data: the array data to display. A large range of datatypes (including Complex32 and UInt16) is supported.

viewer: of interest only for modes "replace" and "add_element". This viewer instance (as returned by previous calls) is used for display.
        Note that this module keeps track of previously invoked viewers. By default the "viewers["active"]" is used.

gamma: The gamma settings to display this data with. By default the setting is 1.0 for real-valued data and 0.3 for complex valued data.

mode: allows the user to switch between display modes by either 
    `mode="new"` (default): invoking a new View5D.view5d instance to display `data` in
    `mode="replace"`: replacing a single element and time position by `data`. Useful to observe iterative changes.
    `mode="add_element"`: adds a single (!) element to the viewer. This can be useful for keeping track of a series of iterative images.
    Note that both modes "replace" and "add_element" only work with a viewer that was previously created via "new".
    Via the "viewer" argument, a specific viewer can be selected. By default the last previously created one is active.
    Note also that it is the user's responsibility to NOT change the size and data-type of the data to display in the modes "replace" and "add_element".

element, time: only used for mode "replace" to specify which element and and time position needs to be replaced. 

#Returns
An instance (JavaCall.JavaObject) or the viewer, which can be used for further manipulation.

#See also
set_gamma: changes the gamma value to display the data (useful for enhancing low signals)
process_keys: allows an easy remote-control of the viewer since almost all of its features can be controlled by key-strokes.

# Example
```julia-repl
julia> using View5D
julia> view5d(rand(6,5,4,3,2)) # a viewer with 5D data should popp up
julia> using TestImages
julia> img1 = Float32.(testimage("resolution_test_512.tif"));
julia> img2 = testimage("mandrill");
julia> img3 = testimage("simple_3d_ball.tif"); # A 3D dataset
julia> v1 = view5d(img1);
julia> v2 = view5d(img2);
julia> v3 = view5d(img3);
```
"""

function view5d(data :: AbstractArray, viewer=nothing; gamma=nothing, mode="new", element=0, time=0)
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

        myJArr, myDataType=to_jtype(data)
        # myJArr=Array{myDataType}(undef, mysize)
        #myJArr[:].=myArray[:]
        # @show size(myJArr)
        # listmethods(V,"Start5DViewer")
        if myDataType <: Complex
            jArr = Vector{jfloat}
            #myviewer=jcall(V, "Start5DViewerC", V, (jArr, jint, jint, jint, jint, jint), myJArr[:], size(myArray,1), size(myArray,2), size(myArray,3), size(myArray,4),size(myArray,5));
            #@show size(data)
            #@show size(myJArr)
            # myviewer=jcall(V, command, V, (jArr, jint, jint, jint, jint, jint), myJArr[:], size(myJArr,1), size(myJArr,2), size(myJArr,3), size(myJArr,4),size(myJArr,5));
            myviewer = start_viewer(viewer, myJArr,jfloat, mode, true)
            if isnothing(gamma)
                gamma=0.3
            end
        else
            #@show size(data)
            #@show size(myJArr)
            myviewer = start_viewer(viewer, myJArr,myDataType, mode)
        end
        #@show typeof(myviewer)
        #@show myviewer
        set_active_viewer(myviewer)
        if !isnothing(gamma)
            set_gamma(gamma,myviewer, element=element)
        end
        process_keys("Ti12", myviewer)   # to initialize the zoom and trigger the display update
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
