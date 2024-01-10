export view5d
export get_last_viewer, get_active_viewer
export process_key_element_window, process_key_main_window, process_keys
export set_axis_scales_and_units, set_value_unit, set_value_name
export repaint, update_panels, to_front, hide_viewer, set_fontsize 
export set_gamma, set_min_max_thresh
export set_element, set_time, set_elements_linked, set_times_linked
export set_element_name, get_num_elements, get_num_times, set_title
export set_display_size, set_active_viewer, set_properties, clear_active
export get_viewer_history, close_all, hide_all, to_front_all
export export_marker_lists, import_marker_lists, delete_all_marker_lists, export_markers_string, empty_marker_list
export DisplayMode, DisplAddElement, DisplAddTime, DisplNew, DisplReplace
export set_view5d_default_size
# export list_methods, java_memory
# export init_layout, invalidate 


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
const View5D_jar = joinpath(rootpath, "View5D_v2.3.8.jar")
# my personal development version
# const View5D_jar = joinpath(rootpath, "View5D_v2.jar")

function __init__()
    # This has to be in __init__ and is invoked by `using View5D`
    # Allows other packages to addClassPath before JavaCall.init() is invoked
    devel_path = joinpath(rootpath, "..","View5D.jar")
    if isfile(devel_path)
        print("Found development version of View5D.jar in the artifact directory. Using this.")
        JavaCall.addClassPath(devel_path)
    else
        JavaCall.addClassPath(View5D_jar)
    end
    default_size = estimate_default_size()
    if !isnothing(default_size)
        set_view5d_default_size(default_size) # overwrites the default size inside the viewer
    end
end

# some heuristics to estimate a good size for initial viewer display.
function estimate_default_size()
    if Base.Sys.iswindows()
        try
            res = readchomp(`wmic desktopmonitor get PixelsPerXLogicalInch`);
            reg = r"\s+(\d+)\s+"x ;
            v = match(reg,res).captures
            sinch = parse(Int,v[1])
            res = readchomp(`wmic desktopmonitor get screenheight`);
            v = match(reg,res).captures
            sres = parse(Int,v[1])
            fsize = sinch * 3
            fsize = min(sres ÷ 2, fsize) 
            return (fsize, fsize)           
        catch e # for some reasons some system do not return the screen size. We need to assume a default
            return (500, 300)
        end
    else
        return nothing
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
    if myviewer==get_active_viewer(false)
        clear_active()
    end
    h = viewers["history"]
    deleteat!(h, findall(x-> x == myviewer, h)) # remove this viewer from the history.
end

function close_viewer(myviewer=nothing)
    myviewer=get_viewer(myviewer)
    try
        process_keys("\$", myviewer)  # closes also the histogram window, which the commented line below does not do
        # jcall(myviewer, "closeAll", Nothing, ()); # for some reason it throws an exception even if deleting everything
    catch e
    end
    remove_viewer(myviewer)
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

#   DOES NOT WORK PROPERLY IN VIEW5D
"""
    set_set_position(pos, myviewer=nothing)

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
function set_position(pos::NTuple{5,Int}, myviewer=nothing)
    myviewer=get_viewer(myviewer)
    # jcall(myviewer, "setPosition", Nothing, (jdouble,jdouble,jdouble,jdouble,jdouble), pos...);
    jcall(myviewer, "setPosition", Nothing, (jint,jint,jint,jint,jint), pos...);
    # update_panels(myviewer)
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
        value_name = "intensity",value_unit = "a.u.",
        axis_names = ["X", "Y", "Z", "E", "T"],
        axis_units=["a.u.","a.u.","a.u.","a.u.","a.u."], myviewer=nothing; 
        element=:,time=:,
        value_offset=0.0,
        offset=[0.0,0.0,0.0,0.0,0.0])

overwrites the units and scaling of all five axes and the value units and scalings.

# Arguments
* `pixelsize`: 5D vector of pixel sizes.
* `value_scale`: the scale of the value axis
* `value_name`: the name of the value axis of this element as a String
* `value_unit`: the unit of the value axis of this element as a String
* `axes_names`: the names of the various (X,Y,Z,E,T) axes as a 5D vector of String
* `axes_units`: the units of the various axes as a 5D vector of String

* `element`: a number of range or empty range `:` spedifying to which element(s) to apply the modifiations to
* `time`: a number of range or empty range `:` spedifying to which time(s) to apply the modifiations to
* `value_offset`: allows to add an offset to the displayed values
* `offset`: allows to add an offset to each of the 5 coordinates

#Example
```jldoctest
julia> v1 = view5d(rand(Int16,6,5,4,2,2))

julia> set_axis_scales_and_units((1,0.02,20,1,2),20,"irradiance","W/cm^2",["position","λ","micro-time","repetition","macro-time"],["mm","µm","ns","#","minutes"],element=0)
```
"""
function set_axis_scales_and_units(pixelsize=(1.0,1.0,1.0,1.0,1.0),
    value_scale=1.0, value_name = "intensity",value_unit = "a.u.",
    axes_names = ["X", "Y", "Z", "E", "T"],
    axes_units=["a.u.","a.u.","a.u.","a.u.","a.u."], myviewer=nothing; 
    element=:,time=:, # meaning all elements
    value_offset=0.0,
    offset=[0.0,0.0,0.0,0.0,0.0])

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
    if isa(element,Colon)
        element = 0:get_num_elements(myviewer)-1
    end
    if isa(time,Colon)
        time = 0:get_num_times(myviewer)-1
    end
    for t in time, e in element
        jcall(myviewer, "SetAxisScalesAndUnits", Nothing, (jint,jint, jdouble,jdouble,jdouble,jdouble,jdouble,jdouble,jdouble,jdouble,jdouble,jdouble,jdouble,jdouble,
                JString,jStringArr,JString,jStringArr),
                e,t, value_scale, pixelsize..., 
                value_offset, offset...,
                value_name, axes_names, value_unit, axes_units);
    end
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
    pos_marker(list, entry, pos)
    creates a marker with only the position `pos` being filled in.
"""
function pos_marker(list, entry, pos=(0f0,))
    pos5 = (n <= length(pos) ? Float32(pos[n]) : 0f0 for n in 1:5)
    Float64.([list, entry, pos5 ..., 1.0, 1.0, pos5 ..., 1.0, 1.0, 0.0, -1.0, -1.0, -1.0, -1.0, -5.377472e6])
end

"""
    empty_marker_list(lists,entries)
creates an empty marker list with the list numbers and (empty) parent connectivity information already filled in.

# Arguments
* lists: number of marker lists to creat
* entries: number of entries in each list
"""
function empty_marker_list(lists,entries)
    [pos_marker((p-1)÷entries, mod(p-1,entries)) for p in 1:lists*entries]
end

"""
    import_marker_lists(marker_lists, myviewer=nothing)
    imports marker lists to be stored and displayed in the viewer.

# Arguments
* `marker_lists`: a vector of `markers`, where `markers` is a vector of length 22 `Float32`. If the vector is smaller the markers are interpreted as up to 5D pixel positions only.
                  You can also submit a vector of vectors of position-tuples (or position-vectors) structured as collection of marker lists. The numbers will be automatically starting from zero.
                  Note that the positions when submitted via these latter modes are Julia-style, i.e. one-based rather than zero based.
* `myviewer`: the viewer to apply this to. By default the active viewer is used

# See also
`export_marker_lists()`: The data exported in this way can be read in again by the `import_marker_lists` routine

# Example:
```jldoctest
julia> a = rand(30,20,10);
julia> @vt rand(30,20,10)
rand(30, 20, 10) = nothing
julia> import_marker_lists([[size(a).*rand(3) for n=1:7] for l=1:3])
```
"""
function import_marker_lists(marker_lists::Vector{T}, myviewer=nothing) where {T}
    myviewer=get_viewer(myviewer)
    marker_lists = let 
        if T <: Number
            [marker_lists]
        else
            marker_lists
        end
    end
    if T <: Vector && (eltype(T) <: Tuple || eltype(T) <: Vector)
        # @show "found list of lists"
        ml = Vector{Float32}[]
        for l in 1:lastindex(marker_lists)
            for n in 1:lastindex(marker_lists[l])
                push!(ml, pos_marker(l-1, n-1, marker_lists[l][n] .- 1))
            end
        end
        marker_lists = ml
    end
    if (length(marker_lists)>0 && length(marker_lists[1]) < 6)
        @show "found list of positions"
        marker_lists = [pos_marker(0, n-1, marker_lists[n] .- 1) for n in 1:lastindex(marker_lists)]
    end
    if eltype(marker_lists) != Float64
        marker_lists = [convert.(Float64, marker_lists[n]) for n in 1:lastindex(marker_lists)]
    end
    # @show marker_lists
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
    myviewer = get_viewer(myviewer, ignore_nothing=true)
    if !isnothing(myviewer)
        close_viewer()
    end
    while ! isempty(viewers["history"]) 
        close_viewer(viewers["history"][end])
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
view5D_settings = Dict() # stores use-definable default settings. E.g. the default display size

"""
    set_view5d_default_size(mysize=(700,700))
    sets a new default size for new View5D viewer windows. This may be an important command to run at startup, to adapt the viewer size
    to your screen resolution.

    If you wan to change the display size of a particular viewer, use the command `set_display_size()`.
"""
function set_view5d_default_size(mysize=(700,700))
    view5D_settings["default_size"] = mysize
end

function get_active_viewer(do_check_alive=true)
    if haskey(viewers,"active")
        myviewer=viewers["active"]
        if do_check_alive
            myviewer = check_alive(myviewer)
        end
    else
        myviewer=nothing
    end
end

function get_last_viewer()
    vh = viewers["history"]
    for n=length(vh):-1:1
        if !isnothing(check_alive(vh[n]))
            return vh[n]
        end
    end
    return nothing
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
            myviewer = nothing # viewers["history"][end];
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
function get_viewer(viewer=nothing; ignore_nothing=false)
    if isnothing(viewer)
        v = get_active_viewer()
        if (! ignore_nothing) && isnothing(v)
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
                @warn "Nonmatching new size $vn does not agree to current size $vs. Starting new viewer instead."
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
        if haskey(view5D_settings,"default_size")
            default_size = view5D_settings["default_size"]
            set_display_size(default_size[1], default_size[2], myviewer)
            process_keys("i", myviewer)
        end

        if !isnothing(properties)  # properties win over name tags for elements
            set_properties(properties, myviewer, element=:,time=:)
        else
                sz = (sizeX,sizeY,sizeZ) # size(data)
                offset=  Float64.(.-[(sz.÷2)...,zeros(5-length(sz))...])
                set_axis_scales_and_units((1.0,1.0,1.0,1.0,1.0), 1.0,  "intensity", "a.u.", ["X", "Y", "Z", "E", "T"], ["rel x","rel x","rel z","a.u.","a.u."], myviewer; offset=offset)
                process_keys("i", myviewer) 
        end
        if !isnothing(name)
            for E in 0:get_num_elements(myviewer)-1
                set_element_name(E, name, myviewer)
            end
            set_title(name, myviewer)
        else
            set_title("View5D", myviewer)
        end
        set_elements_linked(false,myviewer)
        set_times_linked(true,myviewer)
    elseif mode == DisplReplace
        command = string("ReplaceData", addCpx)
        #@show viewer 
        size3d = sizeX*sizeY*sizeZ
        size4d = size3d*sizeE
        if isCpx
            size4d *= 2;
        end
        for t in 0:sizeT-1
            for e in 0:sizeE-1
                offset = e*size3d+t*size4d
                # print("replacing element: $(element+e) and time $(mytime+t), offset: $offset.\n")
                jcall(viewer, command, Nothing, (jint, jint, jArr), element+e, mytime+t, myJArr[offset+1:end]);
                if !isnothing(name)
                    set_element_name(e, name, viewer)
                end
            end
            if !isnothing(properties)
                set_properties(properties, viewer, element=e, time=t)
            end        
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
                # E = get_num_elements()-1
                set_element_name(e, name, viewer)
            end
            myviewer = viewer
            if !isnothing(properties)
                set_properties(properties, myviewer, element=e, time=:)
            end
        end
    elseif mode == DisplAddTime
        ne = get_num_elements(viewer)
        if sizeE > ne
            throw(ArgumentError("Added times, the number of elements $ne in the viewer need to be larger or equation to the elements currently being added $sizeE."))
        end
        command = string("AddTime", addCpx)
        size4d = sizeX*sizeY*sizeZ*sizeE
        if isCpx
            size4d *= 2;
        end
        for t in 0:sizeT-1
            dummy=jcall(viewer, command, V, (jArr, jint, jint, jint, jint, jint),
                            myJArr[t*size4d+1:end],sizeX, sizeY, sizeZ, sizeE, sizeT);
            viewer_sizes[viewer][5] = get_num_times(viewer)
            for e in 0: get_num_elements()-1 # just to normalize colors and set names
                set_element(e) # go to the this element
                if !isnothing(name)
                    set_element_name(e, name, viewer)
                end
                process_keys("t",viewer)
            end
            if !isnothing(properties)
                set_properties(properties, viewer, element=:, time=t)
            end        
            myviewer = viewer
        end
    else
        throw(ArgumentError("unknown mode $mode, choose `DisplNew`, `DisplReplace`, `DisplAddElement` or `DisplAddTime`"))
    end
    to_front(myviewer)
    return myviewer
end

"""
    optional_normalize_display(data, viewer=nothing, element=0, min_ratio=1e6)
Checks the gray-value range of the data and normalizes zero to max in case the relative contrast is below 1e-6.
Otherwise it normalizes min to max.

Arguments:
+ data: Data to dermine normalization from
+ viewer: viewer to apply normalization to
+ element: element to apply it to
+ min_ratio: the minimum contrast ratio (towards zero) to require to do apply min-max rather that zero to max display normalization
"""
function optional_normalize_display(data, viewer=nothing; element=0, min_ratio=1e6)
    if !(eltype(data) <: Real)
        data = abs.(data);
    end
    mymin = minimum(data);
    mymax = maximum(data);
    if ((mymax - mymin)*min_ratio < mymax)
        mymin = 0;
    end
    println("display normalized to $(mymin) to $(mymax).")
    set_min_max_thresh(mymin, mymax, viewer; element=element)
    update_panels(viewer)
end

function add_phase(data, data_element=0, data_time=0, viewer=nothing; name=nothing)
    sz=expand_size(size(data),5)
    # set_time(-1) # go to the last slice
    # process_keys("t") # to normalize the gray value image before we add phase
    optional_normalize_display(data, viewer);
    
    for E in 0:sz[4]-1
        phases = Float32.(180 .*angle.(data)./pi)  # in degrees. Force phase always to be Float32 independet of the Complex datatype.
        # data.unit.append("deg")  # dirty trick
        phase_elem = data_element + sz[4]
        if phase_elem >= get_num_elements(viewer)
            viewer = view5d(phases, viewer; gamma=1.0, mode=DisplAddElement, element=phase_elem, name=name)
            # all color updates need to only be done the first time
            set_element(-1, viewer) # go to the last element.
            process_keys("cccccccccccc", viewer) # toggle color mode 12x to reach the cyclic colormap
            process_keys("56", viewer) # for some reason this avoids dark pixels in the cyclic color display.
            process_keys("vVe", viewer) # Toggle from additive into multiplicative display    
            if sz[4]==1
                process_keys("C", viewer) # Back to Multicolor mode
            end
        else # the element already exists and just needs replacement.
            times = get_num_times(viewer)
            if data_time >= times
                throw(ArgumentError("Trying to add phase to non-existing time point $data_time in the viewer with $times timepoints."))
            end
            # @show "replacing $data_element, $phase_elem, $data_time "
            viewer = view5d(phases, viewer; gamma=1.0, mode=DisplReplace, element=phase_elem, time=data_time, name=name)
        end
        if isnothing(name)
            set_value_name("phase", viewer;element = phase_elem)
        else
            set_value_name(name*"_phase", viewer;element = phase_elem)
        end
        set_value_unit("deg", viewer;element = phase_elem)
        #@show ne+E
        # It is unclear, why this hast o be set to 180.02, but <= 180.01 causes zeros in the phase display!
        set_min_max_thresh(-180.02, 180.02, viewer;element = phase_elem) # to set the color to the correct values
        #update_panels()
        #process_keys("eE") # to normalize this element and force an update also for the gray value image
        #to_front()    

        # process_keys("E", viewer) # advance to next element to the just added phase-only channel
    end
end


# These two should be imported from NDTools
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
function set_properties(properties, myviewer=nothing; element=:,time=:)
    myviewer=get_viewer(myviewer)
    if haskey(properties,:Name) 
        set_title(properties[:Name], myviewer)
    end
    axes_scales = (1.0,1.0,1.0,1.0,1.0)
    axes_names = ["X", "Y", "Z", "E", "T"]
    axes_units=["pix","pix","pix","unknown","unknown"]
    scaV = 1.0 # value scale
    nameV = "intensity"
    unitV = "a.u."
    value_offset=0.0
    if haskey(properties,:Pixels)
        Pixels = properties[:Pixels]
        unitX = haskey(Pixels, :PhysicalSizeXUnit) ? Pixels[:PhysicalSizeXUnit] : "unknown"
        unitY = haskey(Pixels, :PhysicalSizeYUnit) ? Pixels[:PhysicalSizeYUnit] : "unknown"
        unitZ = haskey(Pixels, :PhysicalSizeZUnit) ? Pixels[:PhysicalSizeZUnit] : "unknown"
        unitE = haskey(Pixels, :PhysicalSizeEUnit) ? Pixels[:PhysicalSizeEUnit] : "unknown" #not in the Bioformats-Spec
        unitT = haskey(Pixels, :PhysicalSizeTUnit) ? Pixels[:PhysicalSizeTUnit] : "unknown" #not in the Bioformats-Spec
        scaX = haskey(Pixels, :PhysicalSizeX) ? Pixels[:PhysicalSizeX] : 1.0
        scaY = haskey(Pixels, :PhysicalSizeY) ? Pixels[:PhysicalSizeY] : 1.0
        scaZ = haskey(Pixels, :PhysicalSizeZ) ? Pixels[:PhysicalSizeZ] : 1.0
        scaE = haskey(Pixels, :PhysicalSizeE) ? Pixels[:PhysicalSizeE] : 1.0 #not in the Bioformats-Spec
        scaT = haskey(Pixels, :PhysicalSizeT) ? Pixels[:PhysicalSizeT] : 1.0 #not in the Bioformats-Spec
        scaT = haskey(Pixels, :TimeIncrement) ? Pixels[:TimeIncrement] : scaT
        axes_scales = (scaX,scaY,scaZ,scaE,scaT)
        axes_names = ["X", "Y", "Z", "E", "T"]
        axes_units=[unitX,unitY,unitZ,unitE,unitT]
    end
    if haskey(properties,:axes_scales)
        axes_scales = properties[:axes_scales]
    end
    if haskey(properties,:axes_names)
        axes_names = properties[:axes_names]
    end
    if haskey(properties,:axes_units)
        axes_units = properties[:axes_units]
    end
    offset=[0.0,0.0,0.0,0.0,0.0]
    if haskey(properties,:Plane)
        Plane = properties[:Plane]
        offset[1] = haskey(Plane, :PositionX) ? Plane[:PositionX] : 0.0
        offset[2] = haskey(Plane, :PositionY) ? Plane[:PositionY] : 0.0
        offset[3] = haskey(Plane, :PositionZ) ? Plane[:PositionZ] : 0.0
    elseif haskey(properties,:offset) # the easy way
        if length(properties[:offset]) < 5
            offset[1:length(properties[:offset])] .= properties[:offset]
        else
            offset=properties[:offset][1:5]
        end
    end
    
    set_axis_scales_and_units(axes_scales,scaV, nameV, unitV, 
                            axes_names, axes_units, myviewer,element=element,time=time, value_offset=value_offset, offset=offset)
    if haskey(Pixels,:Channel)
        Channels = Pixels[:Channel]
        if isa(Channels,Dict)
            Channels=[Channels];
        end
        if isa(element, Colon) # In case all elements are supposed to be changed
            element=0
        end
        for c in Channels
            name = haskey(c, :ExcitationWavelength) ? "$(c[:ExcitationWavelength])" : "color $element"
            name = name * "/" * (haskey(c, :EmissionWavelength) ? "$(c[:EmissionWavelength])" : "color $element")
            set_element_name(element, name, myviewer)
            element = element + 1
        end
    end
end

function axes_to_properties(axes)
    properties=Dict();
    Pixels=Dict();
    axes_names=[]
    for (ax, d) in zip(axes, 1:length(axes))
        name = axisnames(ax)[1]
        push!(axes_names, String(name))
        vals = axisvalues(ax)[1] # is a Tuple of StepRange
        s = 1.0
        u = ""
        try
            s = vals.step.hi.val # get the step value
            u = "$(unit(vals.step))"
        catch e
            s = step(ax)
            # try
            #     s = vals.step.hi # for steps without units
            # catch e
            #     s = vals.step # for integer steps
            # end
            u = "µm"
        end
        if d == 1 # name == :x
            Pixels[:PhysicalSizeXUnit] = u
            Pixels[:PhysicalSizeX] = s
        end
        if d == 2 # name == :y
            Pixels[:PhysicalSizeYUnit] = u
            Pixels[:PhysicalSizeY] = s
        end
        if d == 3 # name == :z
            Pixels[:PhysicalSizeZUnit] = u
            Pixels[:PhysicalSizeZ] = s
        end
        if d == 4 # name == :e
            Pixels[:PhysicalSizeEUnit] = u
            Pixels[:PhysicalSizeE] = s
        end
        if d == 5 # name == :t
            Pixels[:PhysicalSizeTUnit] = u
            Pixels[:PhysicalSizeT] = s
        end
    end
    properties[:axes_names] = axes_names
    properties[:Pixels] = Pixels
    return properties
end

TransferType = NamedTuple{(:View5D, :transfer), Tuple{Nothing, NamedTuple}}


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
# @vv, @ve, @vt, @vp, @vep, @vtp: various convenient short-hand macros for displaying the data
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
julia> using Unitful, AxisArrays; view5d(AxisArray(rand(10,11,12,3,4),(:x,:y,:z,:lifetime, :t),(0.1u"µm",0.2u"m",0.3u"µm",0.3u"ns",2.0u"s"))) # display an array with axes and units
```
--------------------------
Note that you can also call view5d with a `Tuple{AbstractArray, NamedTuple}` as the first argument.
The NamedTuple can contain parameters and via :properties also the scaling information.
This allows to easily adapt any array-based datatype to naturally display in view5d with meta-information,
by writing a Base.convert routine such as:
```jldoctest

```
"""
function view5d(data, viewer=nothing; gamma=nothing, mode::DisplayMode =DisplNew, element=0, time=0, show_phase=false, keep_zero=false, name=nothing, title=nothing, properties=nothing)
    if startswith("$(typeof(data))","ImageMeta")
        return view5d_M(data , viewer; gamma=gamma, mode=mode, element=element, time=time, show_phase=show_phase, keep_zero=keep_zero, name=name, title=title)
    end

    try # check if this type is convertible to a special display tuple
        data_prop=convert(TransferType, data)
        data = data_prop[:transfer][:data]
        trans = data_prop[:transfer]
        gamma = replace_param(trans, gamma,:gamma)
        mode = replace_param(trans, mode,:mode)
        show_phase = replace_param(trans, show_phase,:show_phase)
        keep_zero = replace_param(trans, keep_zero,:keep_zero)
        name = replace_param(trans, name,:name)
        title = replace_param(trans, title,:title)
        properties = replace_param(trans, properties,:properties)
        properties = adjust_properties!(properties)
    catch e
        if ! (isa(e, MethodError) && e.f == convert)
            throw(e)
        end
    end
    if !isa(data, AbstractArray)
        return nothing # just ignore this display. The macro will interpret this as "not displayable"
    elseif ndims(data)> 5
        throw(ArgumentError("Data to display has more than 5 dimensions, which is the maximum number of dimensions to display."))
    end

    if isa(data, AxisArray) && isnothing(properties)
        properties = axes_to_properties(data.axes)
    end

    if show_phase && eltype(data)<:Real
            data = Complex.(data) # always cast to complex, if the user wants phase display
    end
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
        set_gamma(gamma,myviewer, element=get_num_elements(viewer)-1)
    end

    if keep_zero
        set_min_max_thresh(0.0,maximum(abs.(data)),myviewer, element=get_num_elements()-1)
    end
    if !isnothing(title)
        set_title(title)
    end
    if show_phase && myDataType <: Complex
        if mode==DisplAddTime
            first_new_time = get_num_times(viewer) - size(data,5)
            add_phase(data, element, first_new_time, myviewer, name=name)
        else
            add_phase(data, element, time, myviewer, name=name)
        end
    end
    update_panels(myviewer)
    return myviewer
end

function getPermutation(ordertuple)
    perm = collect(1:5)
    for d in 1:5
        if ordertuple[d] == :X
            perm[1]=d
        elseif ordertuple[d] == :Y
            perm[2]=d
        elseif ordertuple[d] == :Z
            perm[3]=d
        elseif ordertuple[d] == :C
            perm[4]=d
        elseif ordertuple[d] == :T
            perm[5]=d
        else
            @warn("unknown tag in importorder: $(ordertuple[d])")
        end
    end
    return perm
end

function view5d(data :: Array{SArray{Tuple{N},T,1,N}}, viewer=nothing; gamma=nothing, mode::DisplayMode =DisplNew, element=0, time=0, show_phase=false, keep_zero=false, name=nothing, title=nothing, properties=nothing) where {T,N}
    if ndims(data) <= 3
        data = expand_dims(data,3)
        szdat = size(data)
    else
        error("Vector data only supported up to 3D outer dimensions.")
    end
 
    fullsize = (szdat...,N)
    ndata = Array{eltype(eltype(data))}(undef,fullsize...)
    for i in CartesianIndices(data)
        for d=1:N            
            ndata[Tuple(i)...,d] = data[i][d]
        end
    end
    view5d(ndata, viewer; gamma=gamma, mode=mode, element=element, time=time, show_phase=show_phase, keep_zero=keep_zero, name=name, title=title, properties=properties)
end

# special version for Bioformats or related data types 
function view5d_M(data, viewer=nothing; gamma=nothing, mode::DisplayMode =DisplNew, element=0, time=0, show_phase=false, keep_zero=false, name=nothing, title=nothing)
    if startswith("$(typeof(data))","ImageMeta")
        if typeof(data.data) <:AbstractArray 
            prop=nothing
            axs=nothing
            if hasfield(typeof(data),:properties)
                prop=data.properties
            end
            if !isnothing(prop) && haskey(prop,:ImportOrder)
                perm = getPermutation(prop[:ImportOrder])
                dat = permutedims(data.data, perm)
            else
                if hasfield(typeof(data.data),:axes) 
                    prop=axes_to_properties(data.data.axes)
                end
                if ndims(data.data)==5
                    dat = permutedims(data.data, (3,4,2,5,1))
                else
                    dat = data.data # do we need to switch xy?
                end
            end
            view5d(dat, viewer; gamma=gamma, mode=mode, element=element, time=time, show_phase=show_phase, keep_zero=keep_zero, name=name, title=title, properties=prop)
        else
            @warn("unknown type to display")
        end
    else
        @warn("unknown type to display")
    end
end

function view5d(datatuple :: Union{Tuple, Vector}, viewer=nothing; gamma=nothing, mode::DisplayMode =DisplNew, element=0, time=0, show_phase=false, keep_zero=false, name=nothing, title=nothing)
    for data in datatuple
        view5d(data, viewer; gamma=gamma, mode=mode, element=element, time=time, show_phase=show_phase, keep_zero=keep_zero, name=name, title=title)
    end
end

#=  # DOES NOT WORK:
# a bit of metaprogramming that assings the various properties, if needed
for (var, sym) in zip((Ref(gamma), Ref(show_phase), Ref(keep_zero), Ref(name), Ref(title), Ref(properties)),
    (:gamma, :show_phase, :keep_zero, :name, :title, :properties))
if isnothing(var[]) && haskey(prop,sym)
var[] = prop[sym]
end
end
=#

function replace_param(prop, value, symb)
    if isnothing(value) && haskey(prop,symb)
        value = prop[symb]
    end
    return value
end

function adjust_properties!(properties)
    if isnothing(properties)
        return nothing
    end
    if !haskey(properties,:Pixels) # overwrite only
        Pixels=Dict();
    else
        Pixels=properties[:Pixels]
    end
    if !haskey(properties,:Pixels) && haskey(properties,:pixelsize)
        pixelsize = properties[:pixelsize]
        Pixels[:PhysicalSizeX] = pixelsize[1]
        if length(pixelsize) > 1
            Pixels[:PhysicalSizeY] = pixelsize[2]
        end
        if length(pixelsize) > 2
            Pixels[:PhysicalSizeZ] = pixelsize[3]
        end
        if length(pixelsize) > 3
            Pixels[:PhysicalSizeE] = pixelsize[4]
        end
        if length(pixelsize) > 4
            Pixels[:PhysicalSizeT] = pixelsize[5]
        end
        if isa(properties, NamedTuple)
            properties = Dict(pairs(properties)) # convert into a Dict
        end
    end
    if !haskey(properties,:Pixels) && haskey(properties,:units)
        units = properties[:units]
        Pixels[:PhysicalSizeXUnit] = units[1]
        if length(units) > 1
            Pixels[:PhysicalSizeYUnit] = units[2]
        end
        if length(units) > 2
            Pixels[:PhysicalSizeZUnit] = units[3]
        end
        if length(units) > 3
            Pixels[:PhysicalSizeEUnit] = units[4]
        end
        if length(units) > 4
            Pixels[:PhysicalSizeTUnit] = units[5]
        end
        if isa(properties, NamedTuple)
            properties = Dict(pairs(properties)) # convert into a Dict
        end
    end
    properties[:Pixels] = Pixels
    # @show properties
    return properties
end

#= This version is the entry point for other datatypes, which support also placement and other parameters
function view5d(data_prop, viewer=nothing; gamma=nothing, mode::DisplayMode =DisplNew, element=0, time=0, show_phase=false, keep_zero=false, name=nothing, title=nothing, properties=nothing)
    try
        data_prop=convert(TransferType, data_prop)
    catch e
        if isa(e, MethodError) && e.f == convert
            return nothing  # signal the conversion failure back 
        else
            throw(e)
        end
    end
    data = data_prop[:transfer][:data]
    trans = data_prop[:transfer]
    gamma = replace_param(trans, gamma,:gamma)
    mode = replace_param(trans, mode,:mode)
    show_phase = replace_param(trans, show_phase,:show_phase)
    keep_zero = replace_param(trans, keep_zero,:keep_zero)
    name = replace_param(trans, name,:name)
    title = replace_param(trans, title,:title)
    properties = replace_param(trans, properties,:properties)
    properties = adjust_properties!(properties)
    return view5d(data, viewer; gamma=gamma, mode=mode, element=element, time=time, show_phase=show_phase, keep_zero=keep_zero, name=name, title=title, properties=properties)
end
=#
