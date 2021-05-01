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
export view5d, vv, vp, vt, ve, vep, get_active_viewer
export @vv, @ve, @vp, @vep, @vt
export process_key_element_window, process_key_main_window, process_keys
export set_axis_scales_and_units, set_value_unit, set_value_name
export repaint, update_panels, to_front, hide_viewer, set_fontsize # , close_all
export set_gamma, set_min_max_thresh
export set_element, set_time, set_elements_linked, set_times_linked
export set_element_name, get_num_elements, get_num_times, set_title
export set_display_size, set_active_viewer, set_properties, clear_active
export get_viewer_history, close_all, hide_all, to_front_all
export export_marker_lists, import_marker_lists, delete_all_marker_lists, export_markers_string, empty_marker_list
export DisplayMode, DisplAddElement, DisplAddTime, DisplNew, DisplReplace
# export list_methods, java_memory
# export init_layout, invalidate 

using JavaCall
using LazyArtifacts  # used to be Pkg.artifacts
using Colors, ImageCore
# using JavaShowMethods

""" @enum DisplayMode
diplay modes are subtyped from this abstract type. All modes are subtypes of DisplayMode

* DisplNew, opens a new viewer
* DisplAddElement, adds a new element to an existing viewer
* DisplAddTime, adds a new timepoint to an existing viewer
* DisplReplace, replaces data in an existing viewer
"""
@enum DisplayMode DisplNew DisplAddElement DisplAddTime DisplReplace

""" @enum PanelChoices
this applies to keys sent to the viewer, which can be send to a choice of windows

* PanelMain, refers to the main panel (e.g. XY)
* PanelElement, refers to the element panel (bottom right corner)
"""
@enum PanelChoices PanelMain PanelElement


# This is the proper way to do this via artifacts:
rootpath = artifact"View5D-jar"
# @show rootpath = "C:\\Users\\pi96doc\\Documents\\Programming\\Java\\View5D"
const View5D_jar = joinpath(rootpath, "View5D_v2.3.1.jar")
# my personal development version
# const View5D_jar = joinpath(rootpath, "View5D_v2.jar")

function __init__()
    # This has to be in __init__ and is invoked by `using View5D`
    # Allows other packages to addClassPath before JavaCall.init() is invoked
    devel_path = joinpath(rootpath, "..","View5D.jar")
    if isfile(devel_path)
        print("Found development version of View5D in the artifact directory. Using this.")
        JavaCall.addClassPath(devel_path)
    else
        JavaCall.addClassPath(View5D_jar)
    end
end


Displayable = Union{Tuple,AbstractArray}

is_complex(mat) = eltype(mat) <: Complex

# expanddims(x, ::Val{N}) where N = reshape(x, (size(x)..., ntuple(x -> 1, N)...))
expanddims(x, num_of_dims) = reshape(x, (size(x)..., ntuple(x -> 1, (num_of_dims - ndims(x)))...))

""" 
    list_methods(V, text=nothing)
lists all java methods in the underlying view5d.jar containing "text"
"""
function list_methods(text=nothing, V=nothing)
    if isnothing(V)
        V=get_viewer(V)
    end
    mystrings =listmethods(V)
    r=""
    for s in mystrings 
        if !isnothing(text)
            r = r * (contains("$s",text) ? "$s\n" : "")
        else
            r = r * "$s\n"
        end
    end        
    print(r)
end

"""
    java_memory(verbose=true)
prints the free and total memory of the JVM
"""
function java_memory(verbose=true)
    RT = @jimport java.lang.Runtime
    Runtime = jcall(RT, "getRuntime", RT, ());
    jcall(Runtime, "gc", Nothing, ());
    free_mem = jcall(Runtime, "freeMemory", jlong, ());
    total_mem = jcall(Runtime, "totalMemory", jlong, ());
    if verbose
        print("Total Memory: $(total_mem/1000000) Mb\n")
        print("Free Memory: $(free_mem/1000000) Mb\n")
        print("Used fraction: $(100*(total_mem-free_mem) / total_mem) percent\n")
    end
    return free_mem, total_mem
end

function remove_viewer(myviewer)
    if myviewer==get_active_viewer()
        clear_active()
    end
    h = viewers["history"]
    deleteat!(h, findall(x-> x == myviewer, h)) # remove this viewer from the history.
end

function close_viewer(myviewer=nothing)
    myviewer=get_viewer(myviewer)
    remove_viewer(myviewer)
    try
        process_keys("\$", myviewer)  # closes also the histogram window, which the commented line below does not do
        # jcall(myviewer, "closeAll", Nothing, ()); # for some reason it throws an exception even if deleting everything
    catch e
    end
    #jcall(myviewer, "removeAll", Nothing, ());
    RT = @jimport java.lang.Runtime
    Runtime = jcall(RT, "getRuntime", RT, ());
    jcall(Runtime, "gc", Nothing, ());
end

"""
    set_gamma(gamma=1.0, myviewer=nothing; element=0)

modifies the display `gamma` in myviewer
# Arguments

* `gamma`: defines how the data is displayed via `shown_value = data .^gamma`. 
        More precisely: `clip((data.-low).(high-low)) .^ gamma`
* `myviewer`: The viewer to which this gamma should be applied to. By default the active viewer is used.
* `element`: to which color channel (element) should this gamma be applied to

# Example
```jldoctest
julia> v2 = view5d(rand(Float64,6,5,4,3,1))

julia> set_gamma(0.2,element=1)
```
"""
function set_gamma(gamma=1.0, myviewer=nothing; element=0)
    myviewer=get_viewer(myviewer)
    jcall(myviewer, "SetGamma", Nothing, (jint, jdouble), element, gamma);
    update_panels(myviewer)
end

"""
    set_time(mytime=-1, myviewer=nothing)

sets the display position to mytime. A negative value means last timepoint
# Arguments

* `mytime`: The timepoint to set the viewer to
* `myviewer`: The viewer to which this function applies to. By default the active viewer is used.

# Example
```jldoctest
julia> v2 = view5d(rand(Float64,6,5,4,3,2))

julia> set_time(0) # return to the first time point
```
"""
function set_time(mytime=-1, myviewer=nothing)
    myviewer=get_viewer(myviewer)
    jcall(myviewer, "setTime", Nothing, (jint,), mytime);
    update_panels(myviewer)
end

"""
    set_element(myelement=-1, myviewer=nothing)

sets the display position to mytime. A negative value means last timepoint
# Arguments

* `myelement`: The element position (color) to which the viewer display position is set to
* `myviewer`: The viewer to which this function applies to. By default the active viewer is used.

# Example
```jldoctest
julia> v2 = view5d(rand(Float64,6,5,4,3,1))

julia> set_element(0) # return to the first color channel
```
"""
function set_element(myelement=-1, myviewer=nothing)
    myviewer=get_viewer(myviewer)
    jcall(myviewer, "setElement", Nothing, (jint,), myelement);
    update_panels(myviewer)
end

"""
    set_element_name(element,new_name, myviewer=nothing)
provides a new name to the `element` displayed in the viewer

# Arguments
* `element`: The element to rename
* `new_name`: The new name for the element
* `myviewer`: The viewer to apply this to. By default the active viewer is used.
"""
function set_element_name(element, new_name::String, myviewer=nothing)
    myviewer=get_viewer(myviewer)
    jcall(myviewer, "setName", Nothing, (jint, JString), element, new_name);
    update_panels(myviewer)
end

"""
    set_elements_linked(is_linked::Bool,myviewer=nothing)
provides a new name to the `element` displayed in the viewer

# Arguments
* `is_linked`: defines whether all elements are linked
* `myviewer`: The viewer to apply this to. By default the active viewer is used.
"""
function set_elements_linked(is_linked::Bool, myviewer=nothing)
    myviewer=get_viewer(myviewer)
    jcall(myviewer, "SetElementsLinked", Nothing, (jboolean,), is_linked);
    update_panels(myviewer)
end

"""
    set_times_linked(is_linked::Bool,myviewer=nothing)
    provides a new name to the `element` displayed in the viewer

# Arguments
* `is_linked`: defines whether all times are linked
* `myviewer`: The viewer to apply this to. By default the active viewer is used.
"""
function set_times_linked(is_linked::Bool, myviewer=nothing)
    myviewer=get_viewer(myviewer)
    jcall(myviewer, "setTimesLinked", Nothing, (jboolean,), is_linked);
    update_panels(myviewer)
end

"""
    set_title(title, myviewer=nothing)
sets the title of the viewer

# Arguments
* `title`: new name of the window of the viewer
* `myviewer`: The viewer to apply this to. By default the active viewer is used.
"""
function set_title(title::String, myviewer=nothing)
    myviewer=get_viewer(myviewer)
    jcall(myviewer, "NameWindow", Nothing, (JString,), title);
    update_panels(myviewer)
end

"""
    set_display_size(sx::Int,sy::Int, myviewer=nothing)
sets the size on the screen, the viewer is occupying
    
# Arguments
* `sx`: horizontal size in pixels
* `sy`: vertical size in pixels
* `myviewer`: the viewer to apply this to. By default the active viewer is used.
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

# Arguments
* `myviewer`: the viewer to apply this to. By default the active viewer is used.
"""
function get_num_elements(myviewer=nothing)
    myviewer=get_viewer(myviewer)
    num_elem=jcall(myviewer, "getNumElements", jint, ());
end

"""
    set_axis_scales_and_units(pixelsize=(1.0,1.0,1.0,1.0,1.0),
        value_name = "intensity",value_unit = "photons",
        axis_names = ["X", "Y", "Z", "E", "T"],
        axis_units=["a.u.","a.u.","a.u.","a.u.","a.u."], myviewer=nothing; 
        element=0,time=0)

overwrites the units and scaling of all five axes and the value units and scalings.

# Arguments
* `pixelsize`: 5D vector of pixel sizes.
* `value_scale`: the scale of the value axis
* `value_name`: the name of the value axis of this element as a String
* `value_unit`: the unit of the value axis of this element as a String
* `axes_names`: the names of the various (X,Y,Z,E,T) axes as a 5D vector of String
* `axes_units`: the units of the various axes as a 5D vector of String

#Example
```jldoctest
julia> v1 = view5d(rand(Int16,6,5,4,2,2))

julia> set_axis_scales_and_units((1,0.02,20,1,2),20,"irradiance","W/cm^2",["position","λ","micro-time","repetition","macro-time"],["mm","µm","ns","#","minutes"],element=0)
```
"""
function set_axis_scales_and_units(pixelsize=(1.0,1.0,1.0,1.0,1.0),
    value_scale=1.0, value_name = "intensity",value_unit = "photons",
    axes_names = ["X", "Y", "Z", "E", "T"],
    axes_units=["a.u.","a.u.","a.u.","a.u.","a.u."], myviewer=nothing; 
    element=0,time=0)

    myviewer=get_viewer(myviewer)    
    # the line below set this for all elements and times
    jStringArr = Vector{JString}
    L = length(pixelsize)
    if L != 5
        @warn "pixelsize should be 5D but has only $L entries. Replacing trailing dimensions by 1.0."
        tmp=pixelsize;pixelsize=ones(5); pixelsize[1:L].=tmp[:];
    end
    L = length(axes_names)
    if L != 5
        @warn "axes_names should be 5D but has only $L entries. Replacing trailing dimensions by standard names."
        tmp=axes_names;axes_names=["X","Y","Z","E","T"]; axes_names[1:L].=tmp[:];
    end
    L = length(axes_units)
    if L != 5
        @warn "axes_units should be 5D but has only $L entries. Replacing trailing dimensions by \"a.u.\"."
        tmp=axes_units;axes_units=["a.u.","a.u.","a.u.","a.u.","a.u."]; axes_units[1:L].=tmp[:];
    end
    jcall(myviewer, "SetAxisScalesAndUnits", Nothing, (jint,jint, jdouble,jdouble,jdouble,jdouble,jdouble,jdouble,jdouble,jdouble,jdouble,jdouble,jdouble,jdouble,
            JString,jStringArr,JString,jStringArr),
            element,time, value_scale, pixelsize..., 0,0,0,0,0,0,
            value_name, axes_names, value_unit, axes_units);
    update_panels(myviewer);
end

"""
    set_value_unit(unit::String="a.u.", myviewer=nothing; element::Int=0)
sets the units for the values of a particular element.

# Arguments
* `unit`: a sting with the unit name
* `myviewer`: the viewer to apply this to. By default the active viewer is used.
* `element`:  the element for which to set the unit (count starts with 0)

#see also
`set_axis_scales_and_units`, `set_value_name`
"""
function set_value_unit(unit::String="a.u.", myviewer=nothing; element::Int=0)
    myviewer=get_viewer(myviewer)
    jcall(myviewer, "setUnit", Nothing, (jint, JString), element, unit);
    repaint()
end

"""
    set_value_name(name::String="intensity", myviewer=nothing; element::Int=0)
sets the name for the values of a particular element.

# Arguments
* `name`: a sting with the name
* `myviewer`: the viewer to apply this to. By default the active viewer is used.
* `element`:  the element for which to set the unit (count starts with 0)

#see also
`set_axis_scales_and_units`, `set_value_unit`
"""
function set_value_name(name::String="a.u.", myviewer=nothing; element::Int=0)
    myviewer=get_viewer(myviewer)
    jcall(myviewer, "NameElement", Nothing, (jint, JString), element, name);
    update_panels(myviewer)
end

"""
    set_fontsize(fontsize::Int=12, myviewer=nothing)
sets the fontsize for the text display in the viewer.

# Arguments
* `fontsize`: size of the font in pixels (default is 12px)
* `myviewer`: the viewer to apply this to. By default the active viewer is used.
"""
function set_fontsize(fontsize::Int=12, myviewer=nothing)
    myviewer=get_viewer(myviewer)
    jcall(myviewer, "setFontSize", Nothing, (jint,), fontsize);
end

#= function init_layout(myviewer=nothing; element::Int=0)
    myviewer=get_viewer(myviewer)
    jcall(myviewer, "initLayout", Nothing, (jint,), element);
    update_panels(myviewer)
    repaint(myviewer)
end
 =#
function invalidate(myviewer=nothing)
    myviewer=get_viewer(myviewer)
    jcall(myviewer, "invalidate", Nothing, ());
end

"""
    set_min_max_thresh(Min::Float64, Max::Float64, myviewer=nothing; element::Int=0)
sets the minimum and maximum display ranges for a particular element in the viewer

# Arguments
* `min`: the minimum of the display range of this element
* `max`: the maximum of the display range of this element
* `myviewer`: the viewer to apply this to. By default the active viewer is used.
* `element`:  the element for which to set the unit (count starts with 0)

#see also
`set_axis_scales_and_units`
"""
function set_min_max_thresh(Min::Number=0.0, Max::Number=1.0, myviewer=nothing; element=0)
    myviewer=get_viewer(myviewer)
    jcall(myviewer, "setMinMaxThresh", Nothing, (jint, jdouble, jdouble), element, Min, Max);
    update_panels(myviewer);
end

"""
    get_num_time(myviewer=nothing)
gets the number of currently existing time points in the viewer

# Arguments
* `myviewer`: The viewer to apply this to. By default the active viewer is used.
"""
function get_num_times(myviewer=nothing)
    myviewer=get_viewer(myviewer)
    num_elem=jcall(myviewer, "getNumTime", jint, ());
end

"""
    export_marker_lists(myviewer=nothing)
gets all the marker lists stored in the viewer as an array of double arrays.

# Arguments
* `myviewer`: the viewer to apply this to. By default the active viewer is used

#Returns
* `markers`: an array of arrays of double. They are interpreted as follows:
    `length(markers)`: overall number of markers
    `markers[1]`: information on the first marker in the following order
* `1:2`     ListNr, MarkerNr, 
* `3:7`     PosX,Y,Z,E,T (all raw subpixel position in pixel coordinates)
* `8:9`     Integral (no BG sub), Max (no BG sub),
* `10:16`   RealPosX,Y,Z,E,T,Integral(no BG sub),Max(no BG sub)  (all as above but this time considering the axes units and scales)
* `17:21`   TagInteger, Parent1, Parent2, Child1, Child2
* `22`      ListColor  (coded)
"""
function export_marker_lists(myviewer=nothing)
    myviewer=get_viewer(myviewer)
    jdoubleArrArr = Vector{Vector{jdouble}}
    return jcall(myviewer, "ExportMarkerLists", jdoubleArrArr, ());
end 

"""
    export_markers_string(myviewer=nothing)
    gets all the marker lists stored in the viewer as a string in human readable form.

# Arguments
* `myviewer`: the viewer to apply this to. By default the active viewer is used

# Returns
a string with the first column indicating the column labels (separated by tab)
followed by rows, each representing a single marker with entries separated by tabs in the following order:
* `1:2`     ListNr, MarkerNr, 
* `3:7`     PosX,Y,Z,E,T (all raw subpixel position in pixel coordinates)
* `8:9`     Integral (no BG sub), Max (no BG sub),
* `10:16`   RealPosX,Y,Z,E,T,Integral(no BG sub),Max(no BG sub)  (all as above but this time considering the axes units and scales)
* `17:21`   TagInteger, Parent1, Parent2, Child1, Child2
* `22`      ListColor  (coded)
"""
function export_markers_string(myviewer=nothing)
    myviewer=get_viewer(myviewer)
    jdoubleArrArr = Vector{Vector{jdouble}}
    return jcall(myviewer, "ExportMarkers", JString, ());
end 

"""
    empty_marker_list(lists,entries)
creates an empty marker list with the list numbers and (empty) parent connectivity information already filled in.

# Arguments
* lists: number of marker lists to creat
* entries: number of entries in each list
"""
function empty_marker_list(lists,entries)
    markers = [Float64.([(p-1)÷entries,mod(p-1,entries),0,0,0,0,0,1,0,0,0,0,0,0,1,0,0,-1,-1,-1,-1,-1]) for p in 1:lists*entries]
end

"""
    import_marker_lists(marker_list, myviewer=nothing)
    imports marker lists to be stored and displayed in the viewer.

# Arguments
* `myviewer`: the viewer to apply this to. By default the active viewer is used

# Returns
* `markers`: an array of arrays of double. Please see `export_marker_lists` for a description of the meaning

# See also
export_marker_lists(): The data exported in this way can be read in again by the import_marker_lists routine
"""
function import_marker_lists(marker_lists::Vector{Vector{T}}, myviewer=nothing) where {T}
    myviewer=get_viewer(myviewer)
    if T != Float32
        marker_lists = [convert.(Float32,marker_lists[n]) for n in 1:length(marker_lists)]
    end
    jfloatArrArr = Vector{JavaObject{Vector{jfloat}}}
    converted = JavaCall.convert_arg.(Vector{jfloat}, marker_lists)
    GC.@preserve converted begin
        jcall(myviewer, "ImportMarkerLists", Nothing, (jfloatArrArr,), [c[2] for c in converted]);
    end
    update_panels(myviewer)
    return
end

"""
    delete_all_marker_lists(myviewer=nothing)
deletes all the marker lists, which are stored in the viewer

# Arguments
* `myviewer`: the viewer to apply this to. By default the active viewer is used

# See also:
`export_marker_lists()`, `import_marker_lists()`
"""
function delete_all_marker_lists(myviewer=nothing)
    myviewer=get_viewer(myviewer)
    jcall(myviewer, "DeleteAllMarkerLists", Nothing, ());
    update_panels(myviewer)
    return
end


"""
    to_front(myviewer=nothing)
moves the viewer on top of other windows

# Arguments
* `myviewer`: the viewer to apply this to. By default the active viewer is used
"""
function to_front(myviewer=nothing)
    myviewer=get_viewer(myviewer)
    if !isnothing(myviewer)
        jcall(myviewer, "toFront", Nothing, ());
    end
end

"""
    hide(myviewer=nothing)
hides the viewer. It can be shown again by calling "to_front".
# Arguments
* `myviewer`: the viewer to apply this to. By default the active viewer is used
"""
function hide_viewer(myviewer=nothing)
    myviewer=get_viewer(myviewer)
    if !isnothing(myviewer)
        jcall(myviewer, "minimize", Nothing, ());   # no idea why this does not work at the moment
    end
end

"""
    close_all(myviewer=nothing)
closes all viewers that were opened using the history and frees the memory.

# Arguments
* `myviewer`: the viewer to apply this to. By default the active viewer is used
"""
function close_all(myviewer=nothing)
    close_viewer()
    for v in viewers["history"]
        close_viewer(v)
    end
end

"""
    hide_all(myviewer=nothing)
hides all viewers that were opened using the history.

# Arguments
* `myviewer`: the viewer to apply this to. By default the active viewer is used
"""
function hide_all(myviewer=nothing)
    hide_viewer()
    for v in viewers["history"]
        hide_viewer(v)
    end
end

"""
    to_front_all(myviewer=nothing)
brings all (previously closed) viewers back to the display using the history.

# Arguments
* `myviewer`: the viewer to apply this to. By default the active viewer is used
"""
function to_front_all(myviewer=nothing)
    to_front()
    for v in viewers["history"]
        to_front(v)
    end
end

"""
    get_viewer_history()
returns the java handles for all viewers in the order they were opened.
"""
function get_viewer_history()
    viewers["history"]
end

function update_panels(myviewer=nothing)
    myviewer=get_viewer(myviewer)
    jcall(myviewer, "UpdatePanels", Nothing, ());
    repaint(myviewer);
    to_front(myviewer);
    process_key_main_window('5',myviewer); # do NOT use process_keys here as this causes an infinite loop!
    process_key_main_window('6',myviewer); 
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

# Arguments
* `key`: single key to process inthe element window
* `myviewer`: the viewer to apply this to. By default the active viewer is used
"""
function process_key_element_window(key::Char, myviewer=nothing)
    myviewer=get_viewer(myviewer)
    myviewer=jcall(myviewer, "ProcessKeyElementWindow", Nothing, (jchar,), key);
    # ProcessKeyElementWindow = javabridge.make_method("ProcessKeyElementWindow","(C)V")
end


"""
    process_keys(KeyList::String, myviewer=nothing; mode=PanelMain)
Sends key strokes to the viewer. This allows an easy remote-control of the viewer since almost all of its features can be controlled by key-strokes.
Note that panel-specific keys (e.g."q": switching to plot-diplay) are currently not supported.
For a discription of keys look at the context menu in the viewer. 
More information at https://nanoimaging.de/View5D

# Arguments
* `KeyList`: list of keystrokes (as a String) to successively be processed by the viewer. An update is automatically called afterwards.
* `myviewer`: the viewer to which the keys are send.
* `mode`: determines to which panel the keys are sent to. Currently supported: PanelMain (default) or "element"

# See also
* `process_key_main_window()`: processes a single key in the main window
* `process_key_element_window()`: processes a single key in the element window
"""
function process_keys(KeyList::String, myviewer=nothing; mode::PanelChoices = PanelMain)
    for k in KeyList
        if mode==PanelMain
            process_key_main_window(k, myviewer)
        elseif mode==PanelElement
            process_key_element_window(k, myviewer)
        else
            throw(ArgumentError("unsupported mode $mode. Use `PanelMain` or `PanelElement`"))
        end
        update_panels(myviewer)
    end
    return
end

# myArray= rand(64,64,3,1,1)  # this is the 5D-Array to display
"""
    function to_jtype(something)
converts an array to a jtype array
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
        anArray = collect(permutedims(expanddims(anArray,5),(3,2,4,1,5)))
        #anArray = collect(permutedims(expanddims(anArray,5),(2,3,4,1,5)))
        # @show size(anArray)
    elseif isa(ArrayElement, Gray)
        anArray = rawview(channelview(permutedims(expanddims(anArray,5),(2,1,3,4,5))))        
        # anArray = expanddims(rawview(channelview(anArray)),5)
    end
    ArrayElement = anArray[1]
    if isa(ArrayElement, Float32)
        jtype=jfloat
    elseif isa(ArrayElement, Float64)
        jtype=jdouble
    elseif isa(ArrayElement, UInt8)
        jtype=jbyte  # fake it...
        anArray = reinterpret(Int8,anArray)
    elseif isa(ArrayElement, Int8) || isa(ArrayElement, Bool)
        jtype=jbyte
    elseif isa(ArrayElement, UInt16)
        jtype=jchar
    elseif isa(ArrayElement, Int16)
        jtype=jshort
    elseif isa(ArrayElement, Int32)
        jtype=jint 
    elseif isa(ArrayElement, UInt32)
        jtype=jdouble
    elseif isa(ArrayElement, Int)
        jtype=jdouble
    elseif isa(ArrayElement, UInt)
        jtype=jdouble
    else
        mytype= typeof(ArrayElement)
        throw(ArgumentError("Datatype $mytype to display is not supported"))
    end
    # mysize = prod(size(anArray))
    anArray = expanddims(anArray,5) # permutedims(expanddims(anArray,5),(2,1,3,4,5))  # 
    myJArr=Array{jtype}(undef, size(anArray))
    myJArr[:] .= anArray[:]
    #@show jtype
    #@show size(myJArr)
    return (myJArr,jtype)
end

viewers = Dict() # Ref[Dict] storing viewer 
viewer_sizes = Dict() # storing the current size information as a tuple for each viewer

function get_active_viewer()
    if haskey(viewers,"active")
        myviewer=viewers["active"]    
    else
        myviewer=nothing
    end
end

"""
    clear_active()
clears the active viewer. This is useful in front of for loops, if you want to use `vt` or `ve` as display methods.
##Example:
```jldoctest
julia> clear_active(); for iter in 1:10 vt(rand(5,5,4,3,1), name="Iteration \$(iter)") end
created data 3

```
"""
function clear_active()
    set_active_viewer(nothing)
end

"""
    set_active_viewer(myviewer=nothing)
sets the active viewer to a specific instance. If called with no arguments the last entry in the viewer history is used.
This is convenient, if an active viewer was closed (e.g. by the user) and we want to continue work on  a previous viewer.
"""
function set_active_viewer(myviewer=nothing)
    viewers["active"] = myviewer
    if haskey(viewers,"history")
        if isnothing(myviewer)
            myviewer = viewers["history"][end];
            viewers["active"] = myviewer
        end
        push!(viewers["history"],  myviewer) 
    else
        viewers["history"] = Any[] # needs to be Any here to avoid type conversions
        push!(viewers["history"],  myviewer);
    end
    return nothing
end

function check_alive(viewer)
    if isnothing(viewer)
        return nothing
    else
        try
            # do NOT use the wrapped function as this causes an infinite loop
            num_elem=jcall(viewer, "getNumElements", jint, ());
            if num_elem >= 0
                return viewer
            else
                @warn "View5D: viewer not existing."
                remove_viewer(viewer)
                return nothing
            end
        catch
            @warn "View5D: viewer not existing."
            remove_viewer(viewer)
            return nothing
        end
    end    
end

# if newsize does not agree to active size a new viewer is returned instead
function get_viewer(viewer=nothing)
    if isnothing(viewer)
        v = get_active_viewer()
        if isnothing(v)
            throw(ArgumentError("View5D: no active viewer present."))
            # @warn "View5D: no active viewer exists."
        end
    else
        v = viewer
    end
    v = check_alive(v)
end

function start_viewer(viewer, myJArr, jtype="jfloat", mode::DisplayMode = DisplNew, isCpx=false; 
         element=0, mytime=0, name=nothing, properties=nothing)
    if mode == DisplAddElement && size(myJArr,4)>1  # for more than one element and time added simulateneously we need to add the elements individually
        for e in 1:size(myJArr,4)
            viewer = start_viewer(viewer, collect(myJArr[:,:,:,e:e,:]), jtype, mode, isCpx, element=element, mytime=mytime, name=name)
        end
        return viewer
    end
    jArr = Vector{jtype}
    #@show size(myJArr)
    sizeX,sizeY,sizeZ,sizeE,sizeT = size(myJArr)
    addCpx = ""
    if isCpx
        sizeX = Int(sizeX/2)
        addCpx = "C"
    end

    V = @jimport view5d.View5D
    if isnothing(viewer)
        viewer = get_active_viewer();
    end

    if isnothing(viewer)  # checks about the need to create a new viewer
        mode = DisplNew  # ignores the user request and opens a new viewer to avoid a problem in the View5D java program
    else 
        vs = viewer_sizes[viewer][1:3]
        vn = [sizeX,sizeY,sizeZ]
        if isnothing(vs) || vs != vn
            if mode != DisplNew
                @warn "Nonmatching new size $vn does not agree to current size $vs. Startin new viewer instead."
            end
            mode = DisplNew  # ignores the user request and opens a new viewer to avoid a problem in the View5D java program
        end
    end

    if isnothing(viewer)
        viewer=V
    end

    if mode == DisplNew # create a new viewer
        command = string("Start5DViewer", addCpx)
        myviewer=jcall(V, command, V, (jArr, jint, jint, jint, jint, jint),
                        myJArr[:], sizeX, sizeY, sizeZ, sizeE, sizeT);
        viewer_sizes[myviewer] = [sizeX,sizeY,sizeZ,sizeE,sizeT]

        if !isnothing(name)
            for E in 0:get_num_elements(myviewer)-1
                set_element_name(E, name, myviewer)
            end
            set_title(name, myviewer)
        else
            set_title("View5D", myviewer)
        end
        if !isnothing(properties)  # properties win over name tags for elements
            set_properties(properties, myviewer, element=element)
        end        
        set_elements_linked(false,myviewer)
        set_times_linked(true,myviewer)
    elseif mode == DisplReplace
        command = string("ReplaceData", addCpx)
        #@show viewer 
        for t in 0:sizeE-1
            for e in 0:sizeT-1
                jcall(viewer, command, Nothing, (jint, jint, jArr), element+e, mytime+t, myJArr[:]);
                if !isnothing(name)
                    set_element_name(e, name, myviewer)
                end
            end
        end
        if !isnothing(properties)
            set_properties(properties, myviewer, element=element)
        end        
        myviewer = viewer
    elseif mode == DisplAddElement
        command = string("AddElement", addCpx)
        nt = get_num_times(viewer)
        if sizeT != nt
            throw(ArgumentError("Added elements, the number of times $nt in the viewer need to corrspond to the time dimension of this data $sizeT."))
        end
        size3d = sizeX*sizeY*sizeZ
        for e in 0:sizeE-1
            dummy=jcall(viewer, command, V, (jArr, jint, jint, jint, jint, jint),
                            myJArr[e*size3d+1:end],sizeX, sizeY, sizeZ, sizeE, sizeT); 
            viewer_sizes[viewer][4] = get_num_elements(viewer)  # to also account for user deletes
            viewer_sizes[viewer][5] = get_num_times(viewer)
            # viewer_sizes[myviewer] = viewer_sizes[viewer] # one would assume that the reference does not change but it does ...
            set_element(-1) # go to the last element
            process_keys("t",viewer)   
            if !isnothing(name)
                E = get_num_elements()-1
                set_element_name(E, name, viewer)
            end
            myviewer = viewer
        end
        if !isnothing(properties)
            set_properties(properties, myviewer, element=element)
        end
    elseif mode == DisplAddTime
        ne = get_num_elements(viewer)
        if sizeE != ne
            throw(ArgumentError("Added times, the number of elements $ne in the viewer need to corrspond to the time dimension of this data $sizeE."))
        end
        command = string("AddTime", addCpx)
        size4d = sizeX*sizeY*sizeZ*sizeE
        for t in 0:sizeT-1
            dummy=jcall(viewer, command, V, (jArr, jint, jint, jint, jint, jint),
                            myJArr[t*size4d+1:end],sizeX, sizeY, sizeZ, sizeE, sizeT);
            viewer_sizes[viewer][5] = get_num_times(viewer)
            # viewer_sizes[myviewer] = viewer_sizes[viewer] # one would assume that the reference does not change but it does ...
            set_time(-1) # go to the last element
            for e in 0: get_num_elements()-1 # just to normalize colors and set names
                set_element(e) # go to the this element
                process_keys("t",viewer)
                if !isnothing(name)
                    set_element_name(e, name, viewer)
                end
            end
            if !isnothing(properties)
                set_properties(properties, viewer, element=element)
            end        
            myviewer = viewer
        end
    else
        throw(ArgumentError("unknown mode $mode, choose `DisplNew`, `DisplReplace`, `DisplAddElement` or `DisplAddTime`"))
    end
    to_front(myviewer)
    return myviewer
end

function add_phase(data, start_element=1, viewer=nothing; name=nothing)
    ne = start_element
    sz=expand_size(size(data),5)
    set_time(-1) # go to the last slice
    for E in 0:sz[4]-1
        phases = 180 .*(angle.(data).+pi)./pi  # in degrees
        # data.unit.append("deg")  # dirty trick
        if get_num_times(viewer) == 1
            viewer = view5d(phases, viewer; gamma=1.0, mode=DisplAddElement, element=ne+E+1, name=name)
            # all color updates need to only be done the first time
            set_element(-1, viewer)
            process_keys("cccccccccccc", viewer) # toggle color mode 12x to reach the cyclic colormap
            process_keys("56", viewer) # for some reason this avoids dark pixels in the cyclic color display.
            process_keys("vVe", viewer) # Toggle from additive into multiplicative display    
        else
            el = ne+E
            ti = get_num_times(viewer)-1
            # @show "replacing $start_element, $E, $el, $ti "
            viewer = view5d(phases, viewer; gamma=1.0, mode=DisplReplace, element=el, time=ti, name=name)
        end
        if isnothing(name)
            set_value_name("phase", viewer;element=ne+E)
        else
            set_value_name(name*"_phase", viewer;element=ne+E)
        end
        set_value_unit("deg", viewer;element=ne+E)
        #@show ne+E
        set_min_max_thresh(0.0, 360.0, viewer;element=ne+E) # to set the color to the correct values
        #update_panels()
        #process_keys("eE") # to normalize this element and force an update also for the gray value image
        #to_front()    

        # process_keys("E", viewer) # advance to next element to the just added phase-only channel
    end
    if sz[4]==1
        process_keys("C", viewer) # Back to Multicolor mode
    end
end


function expand_dims(x, N)
    return reshape(x, (size(x)..., ntuple(x -> 1, (N - ndims(x)))...))
end

function expand_size(sz::NTuple, N)
    return (sz..., ntuple(x -> 1, (N - length(sz)))...)
end

"""
    set_properties(properties, myviewer; element)
sets various properties in the viewer in dependence of present entries in the `properties` dictionary.
Arguments:
* properties: The dictionary containing the property information as for example returned by `BioformatsLoader`. See below for details.
* myviewer: optional argument; viewer to apply the settings to.
* element: the element to start with
* time: the time to start with
Currently used properties are:
    `properties[:Pixels][:PhysicalSizeYUnit]`
    `properties[:Pixels][:PhysicalSizeXUnit]`
    `properties[:Pixels][:PhysicalSizeZUnit]`
"""
function set_properties(properties, myviewer=nothing; element=0)
    myviewer=get_viewer(myviewer)
    if haskey(properties,:Name) 
        set_title(properties[:Name], myviewer)
    end
    if haskey(properties,:Pixels)
        Pixels = properties[:Pixels]
        unitX = haskey(Pixels, :PhysicalSizeXUnit) ? Pixels[:PhysicalSizeXUnit] : "unknown"
        unitY = haskey(Pixels, :PhysicalSizeYUnit) ? Pixels[:PhysicalSizeYUnit] : "unknown"
        unitZ = haskey(Pixels, :PhysicalSizeZUnit) ? Pixels[:PhysicalSizeZUnit] : "unknown"
        unitE = "unknown"
        unitT = "unknown"
        scaX = haskey(Pixels, :PhysicalSizeX) ? Pixels[:PhysicalSizeX] : 1.0
        scaY = haskey(Pixels, :PhysicalSizeY) ? Pixels[:PhysicalSizeY] : 1.0
        scaZ = haskey(Pixels, :PhysicalSizeZ) ? Pixels[:PhysicalSizeZ] : 1.0
        scaE = 1.0 # haskey(Pixels, :PhysicalSizeZ) ? Pixels[:PhysicalSizeZ] : "unknown"
        scaT = 1.0 #haskey(Pixels, :PhysicalSizeZ) ? Pixels[:PhysicalSizeZ] : "unknown"
        scaV = 1.0 # value scale
        nameV = "intensity"
        unitV = "a.u."
        axes_scales = (scaX,scaY,scaZ,scaE,scaT)
        axes_names = ["X", "Y", "Z", "E", "T"]
        axes_units=[unitX,unitY,unitZ,unitE,unitT]
    set_axis_scales_and_units(axes_scales,scaV, nameV, unitV, 
                                axes_names, axes_units, myviewer,element=element,time=0)
    if haskey(Pixels,:Channel)
        Channels = Pixels[:Channel]
        for c in Channels
            name = haskey(c, :ExcitationWavelength) ? "$(c[:ExcitationWavelength])" : "color $element"
            name = name * "/" * (haskey(c, :EmissionWavelength) ? "$(c[:EmissionWavelength])" : "color $element")
            set_element_name(element,name, myviewer)
            element = element + 1
        end
    end
    end
end

"""
    view5d(data, viewer=nothing; 
         gamma=nothing, mode=DisplNew, element=0, time=0, 
         show_phase=false, keep_zero=false, name=nothing, title=nothing, properties=nothing)
         
Visualizes images and arrays via a Java-based five-dimensional viewer "View5D".
The viewer is interactive and support a wide range of user actions. 
For details see https://nanoimaging.de/View5D

# Arguments
* `data`: the array data to display. A large range of datatypes (including Complex32 and UInt16) is supported.
           `data` can also be an `NTuple` which causes the viewer to be called for each element of the tuple.
           `data` can also be of type `Image`
           `data` can also be `ImageMetadata.ImageMeta` as returned by the `bf_import` function of the package `BioformatsLoader.jl`.
* `viewer`: of interest only for modes DisplReplace and DisplAddElement. This viewer instance (as returned by previous calls) is used for display.
        Note that this module keeps track of previously invoked viewers. By default the "viewers["active"]" is used.
* `gamma`: The gamma settings to display this data with. By default the setting is 1.0 for real-valued data and 0.3 for complex valued data.
* `mode`: allows the user to switch between display modes by either 
    `mode=DisplNew` (default): invoking a new View5D.view5d instance to display `data` in
    `mode=DisplReplace`: replacing a single element and time position by `data`. Useful to observe iterative changes.
    `mode=DisplAddElement`, `mode=DisplAddTime`: adds a single (!) element (or timepoint) to the viewer. This can be useful for keeping track of a series of iterative images.
    Note that the modes DisplReplace, DisplAddElement adn DisplAddTime only work with a viewer that was previously created via DisplNew.
    Via the "viewer" argument, a specific viewer can be selected. By default the last previously created one is active.
    Note also that it is the user's responsibility to NOT change the size and data-type of the data to display in the modes DisplReplace and DisplAddElement.
* `element`, `time`: used for mode DisplReplace to specify which element and and time position needs to be replaced. 
* `show_phase`: determines whether for complex-valued data an extra phase channel is added in multiplicative mode displaying the phase as a value colormap
* `keep_zero`: if true, the brightness display is initialized with a minimum of zero. See also: `set_min_max_thresh()`.
* `name`: if not nothing, sets the name of the added data. The can be useful debug information.
* `title`: if not nothing, sets the initial title of the display window.
* `properties`: This is expected to be a Dictionary such as returned by `BioformatsLoader`. See `set_properties()` for details on the used entries.

# Returns
An instance (JavaCall.JavaObject) or the viewer, which can be used for further manipulation.

# See also
* `set_gamma()`: changes the gamma value to display the data (useful for enhancing low signals)
* `process_keys()`: allows an easy remote-control of the viewer since almost all of its features can be controlled by key-strokes.

# Example
```jldoctest
julia> using View5D
julia> view5d(rand(6,5,4,3,2)) # a viewer with 5D data should popp up
julia> using TestImages
julia> img1 = transpose(Float32.(testimage("resolution_test_512.tif")));
julia> img2 = testimage("mandrill");
julia> img3 = testimage("simple_3d_ball.tif"); # A 3D dataset
julia> v1 = view5d(img1);
julia> v2 = view5d(img2);
julia> v3 = view5d(img3);
julia> using IndexFunArrays
julia> view5d(exp_ikx((100,100),shift_by=(2.3,5.77)).+0, show_phase=true)  # shows a complex-valued phase ramp with cyclic colormap
```
"""
function view5d(data :: AbstractArray, viewer=nothing; gamma=nothing, mode::DisplayMode =DisplNew, element=0, time=0, show_phase=false, keep_zero=false, name=nothing, title=nothing, properties=nothing)
    if ! JavaCall.isloaded()        
        # Uses classpath set in __init__
        JavaCall.init()
        @info "Initializing JavaCall with classpath" JavaCall.getClassPath()
    end
    #V = @JavaCall.jimport view5d.View5D

    myJArr, myDataType=to_jtype(collect(data))
    # myJArr=Array{myDataType}(undef, mysize)
    #myJArr[:].=myArray[:]
    # @show size(myJArr)
    # listmethods(V,"Start5DViewer")
    if myDataType <: Complex
        jArr = Vector{jfloat}
        myviewer = start_viewer(viewer, myJArr,jfloat, mode, true, name=name, element=element, mytime=time, properties=properties)
        set_min_max_thresh(0.0, maximum(abs.(myJArr)), myviewer, element = get_num_elements(myviewer)-1)
        if isnothing(gamma)
            gamma=0.3
        end
    else
        myviewer = start_viewer(viewer, myJArr,myDataType, mode, name=name, element=element, mytime=time, properties=properties)
    end
    set_active_viewer(myviewer)
    # process_keys("Ti12", myviewer)   # to initialize the zoom and trigger the display update
    if !isnothing(gamma)
        set_gamma(gamma,myviewer, element=get_num_elements()-1)
    end
    if keep_zero
        set_min_max_thresh(0.0,maximum(abs.(data)),myviewer, element=get_num_elements()-1)
    end
    if !isnothing(title)
        set_title(title)
    end
    if show_phase && myDataType <: Complex
        if mode==DisplAddTime
            add_phase(data, 1, myviewer, name=name)
        else
            add_phase(data, size(data,4), myviewer, name=name)
        end
    end
    update_panels(myviewer)
    return myviewer
end

# special version for Bioformats type data
function view5d(data :: Vector, viewer=nothing; gamma=nothing, mode::DisplayMode =DisplNew, element=0, time=0, show_phase=false, keep_zero=false, name=nothing, title=nothing)
    if startswith("$(typeof(data[1]))","ImageMetadata.ImageMeta")
        if typeof(data[1].data) <:AbstractArray 
            dat = permutedims(data[1].data, (3,4,2,5,1))
            prop=nothing
            try prop=data[1].properties
            catch e
            end
            view5d(dat, viewer; gamma=gamma, mode=mode, element=element, time=time, show_phase=show_phase, keep_zero=keep_zero, name=name, title=title, properties=prop)
        else
            @warn("unknown type to display")
        end
    else
        @warn("unknown type to display")
    end
end

function view5d(datatuple :: Tuple, viewer=nothing; gamma=nothing, mode::DisplayMode =DisplNew, element=0, time=0, show_phase=false, keep_zero=false, name=nothing, title=nothing)
    for data in datatuple
        view5d(data, viewer; gamma=gamma, mode=mode, element=element, time=time, show_phase=show_phase, keep_zero=keep_zero, name=name, title=title)
    end
end

"""
    vv(data, viewer=nothing; 
         gamma=nothing, mode=DisplNew, element=0, time=0, 
         show_phase=true, keep_zero=false, title=nothing)

Visualizes images and arrays via a Java-based five-dimensional viewer "View5D".
The viewer is interactive and support a wide range of user actions. 
For details see https://nanoimaging.de/View5D
This is just a shorthand for the function `view5d`. See `view5d` for arguments description.
See documentation of `view5d` for explanation of the parameters.
"""
function vv(data :: Displayable, viewer=nothing; gamma=nothing, mode::DisplayMode =DisplNew, element=0, time=0, show_phase=false, keep_zero=false, name=nothing, title=nothing)
    view5d(data, viewer; gamma=gamma, mode=mode, element=element, time=time, show_phase=show_phase, keep_zero=keep_zero, name=name, title=title)
end

function display_array(arr::Displayable, name, disp=vv) # AbstractArray{N,T} where {N,T}
    disp(arr,name=name)
    return "in_view5d"
end

function display_array(ex, name, disp=vv)
    repr(begin local value = ex end) # returns a representation (a String)
end

using Base

"""
    vp(data, viewer=nothing; 
         gamma=nothing, mode=DisplNew, element=0, time=0, 
         show_phase=true, keep_zero=false, title=nothing)

Visualizes images and arrays via a Java-based five-dimensional viewer "View5D".
The viewer is interactive and support a wide range of user actions. 
For details see https://nanoimaging.de/View5D
This is just a shorthand (with `show_phase=true`) for the function `view5d`. See `view5d` for arguments description.
See documentation of `view5d` for explanation of the parameters.
"""
function vp(data::Displayable, viewer=nothing; gamma=nothing, mode::DisplayMode =DisplNew, element=0, time=0, show_phase=true, keep_zero=false, name=nothing, title=nothing)
    view5d(data, viewer; gamma=gamma, mode=mode, element=element, time=time, show_phase=show_phase, keep_zero=keep_zero, name=name, title=title)
end

"""
    ve(data, viewer=nothing; 
         gamma=nothing, element=0, time=0, 
         show_phase=true, keep_zero=false, title=nothing, elements_linked=false)

Visualizes images and arrays via a Java-based five-dimensional viewer "View5D".
The viewer is interactive and support a wide range of user actions. 
For details see https://nanoimaging.de/View5D
This is just a shorthand adding an element to an existing viewer (mode=`add_element`) for the function `view5d`. See `view5d` for arguments description.
See documentation of `view5d` for explanation of the parameters.

`elements_linked`: determines wether all elements are linked together (no indidual scaling and same color)
"""
function ve(data::Displayable, viewer=nothing; gamma=nothing, element=0, time=0, show_phase=false, keep_zero=false, name=nothing, title=nothing, elements_linked=false)
    viewer = get_viewer(viewer)
    if isnothing(viewer)
        vv(data, viewer; gamma=gamma, mode=DisplNew, element=element, time=time, show_phase=show_phase, keep_zero=keep_zero, name=name, title=title)
    else
        set_elements_linked(elements_linked, viewer)
        vv(data, viewer; gamma=gamma, mode=DisplAddElement, element=element, time=time, show_phase=show_phase, keep_zero=keep_zero, name=name, title=title)
    end
end

"""
    vt(data, viewer=nothing; 
         gamma=nothing, element=0, time=0, 
         show_phase=true, keep_zero=false, title=nothing, times_linked=false)

Visualizes images and arrays via a Java-based five-dimensional viewer "View5D".
The viewer is interactive and support a wide range of user actions. 
For details see https://nanoimaging.de/View5D
This is just a shorthand adding an new time point to an existing viewer (mode=`add_time`) for the function `view5d`. See `view5d` for arguments description.
See documentation of `view5d` for explanation of the parameters.

`times_linked`: determines wether all time points are linked together (no indidual scaling)
##Example:
```jldoctest
julia> clear_active(); for iter in 1:10 vt(rand(5,5,4,3,1), name="Iteration \$(iter)") end
created data 3

```
"""
function vt(data :: Displayable, viewer=nothing; gamma=nothing, element=0, time=0, show_phase=false, keep_zero=false, name=nothing, title=nothing, times_linked=false)
    viewer = get_viewer(viewer);
    if isnothing(viewer)
        vv(data, viewer; gamma=gamma, mode=DisplNew, element=element, time=time, show_phase=show_phase, keep_zero=keep_zero, name=name, title=title)
    else
        set_times_linked(times_linked, viewer)
        vv(data, viewer; gamma=gamma, mode=DisplAddTime, element=element, time=time, show_phase=show_phase, keep_zero=keep_zero, name=name, title=title)
    end
end

"""
    vep(data, viewer=nothing; 
         gamma=nothing, element=0, time=0, 
         show_phase=true, keep_zero=false, title=nothing)

Visualizes images and arrays via a Java-based five-dimensional viewer "View5D".
The viewer is interactive and support a wide range of user actions. 
For details see https://nanoimaging.de/View5D
This is just a shorthand (with `show_phase=true`) adding an element to an existing viewer (mode=`add_element`) for the function `view5d`. See `view5d` for arguments description.
See documentation of `view5d` for explanation of the parameters.
"""
function vep(data :: Displayable, viewer=nothing; gamma=nothing, element=0, time=0, show_phase=true, keep_zero=false, name=nothing, title=nothing)
    ve(data, viewer; gamma=gamma, element=element, time=time, show_phase=show_phase, keep_zero=keep_zero, name=name, title=title)
end

## just a non-exported helper function to be used in the various macros below
function do_start(exs;mystarter=vv)
    blk = Expr(:block)
    alt_name=nothing
    for ex in exs
        varname = sprint(Base.show_unquoted, ex)
        value = ""
        if isnothing(alt_name)            
            name = :(println($(esc(varname))*" = ",
                begin local value=display_array($(esc(ex)),$(esc(varname)),$(mystarter)) end))
        else
            name = :(println($(esc(varname))*" = ",
                begin local value=display_array($(esc(ex)),$(esc(alt_name)),$(mystarter)) end))
        end
        push!(blk.args, name)
        if typeof(ex)==String
            alt_name = ex
        else 
            alt_name = nothing
        end
    end
    isempty(exs) || # push!(blk.args, :value)
    return blk
end

"""
    @vv expressions
a conveniance macro in its usage similar to `@show`. 
The array-like expressions are displayed by opening a viewer for each such array.
The expression also constitutes the name of the displayed data in the viewer.
A string in this list of expressions in front of an array is interpreted as a replacement for the name.
Note that variables of String type or expressions in strings do currently not work. 
## Example
```jldoctest
julia> @vv "Some random RGB" rand(5,6,7,3,2)
"Some random RGB" = "Some random RGB"
created data 3
rand(5, 6, 7, 3, 2) = in_view5d
```
"""
macro vv(exs...)
    do_start(exs; mystarter=vv)
end

"""
    @ve expressions
a conveniance macro in its usage similar to `@show`, displaying several array in a joined viewer or adding to an alraedy existing viewer as new elements. 
The expression typically also constitutes the name of the displayed data in the viewer.
A string in this list of expressions in front of an array is interpreted as a replacement for the name.
Note that variables of String type or expressions in strings do currently not work. 
## Example
```jldoctest
julia> @vv "Some random RGB" rand(5,4,7,3,2)
"Some random RGB" = "Some random RGB"
created data 3
rand(5, 4, 7, 3, 2) = in_view5d

julia> @ve "more random stuff" rand(5,4,7,1,2)
"more random stuff" = "more random stuff"
rand(5, 4, 7, 1, 2) = in_view5d

```
"""
macro ve(exs...)
    do_start(exs; mystarter=ve)
end

"""
    @vp expressions
a conveniance macro in its usage similar to `@show`, displaying also phase information using view5d. See `@vv` and `vp` for details. 
"""
macro vp(exs...)
    do_start(exs; mystarter=vp)
end

"""
    @vt expressions
a conveniance macro in its usage similar to `@show`, displaying several array in a joined viewer or adding to an alraedy existing viewer as new time points. 
The expression typically also constitutes the name of the displayed data in the viewer.
A string in this list of expressions in front of an array is interpreted as a replacement for the name.
Note that variables of String type or expressions in strings do currently not work. 
```
"""
macro vt(exs...)
    do_start(exs; mystarter=vt)
end

macro vep(exs...)
    do_start(exs; mystarter=vep)
end

end # module

#=  Missing implementations from Java:
ImportMarkers = javabridge.make_method("ImportMarkers","([[F)V")
=#
