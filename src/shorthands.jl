export vv, vp, vt, ve, vep, vtp, vr, vrp
export @vv, @ve, @vp, @vep, @vt, @vtp, @vr, @vrp

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
function vv(data, viewer=nothing; gamma=nothing, mode::DisplayMode =DisplNew, element=0, time=0, show_phase=false, keep_zero=false, name=nothing, title=nothing)
    view5d(data, viewer; gamma=gamma, mode=mode, element=element, time=time, show_phase=show_phase, keep_zero=keep_zero, name=name, title=title)
end

function display_array(arr, name, disp=vv, viewer=nothing) # AbstractArray{N,T} where {N,T}
    v=disp(arr,viewer; name=name)
    if isnothing(v)
        v= nothing # repr(begin local value = arr end) # returns a representation (a String)
    end
    return v
    # return "in_view5d"
end

# function display_array(ex, name, disp=vv, viewer=nothing)
#    repr(begin local value = ex end) # returns a representation (a String)
# end

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
function vp(data, viewer=nothing; gamma=nothing, mode::DisplayMode =DisplNew, element=0, time=0, show_phase=true, keep_zero=false, name=nothing, title=nothing)
view5d(data, viewer; gamma=gamma, mode=mode, element=element, time=time, show_phase=show_phase, keep_zero=keep_zero, name=name, title=title)
end

"""
ve(data, viewer=nothing; 
     gamma=nothing, element=0, time=0, 
     show_phase=true, keep_zero=false, title=nothing, elements_linked=false)

Visualizes images and arrays via a Java-based five-dimensional viewer "View5D".
The viewer is interactive and support a wide range of user actions. 
For details see https://nanoimaging.de/View5D
This is just a shorthand adding an element to an existing viewer (mode=DisplAddElement) for the function `view5d`. See `view5d` for arguments description.
See documentation of `view5d` for explanation of the parameters.

`elements_linked`: determines wether all elements are linked together (no indidual scaling and same color)
"""
function ve(data, viewer=nothing; gamma=nothing, element=0, time=0, show_phase=false, keep_zero=false, name=nothing, title=nothing, elements_linked=false)
    viewer = get_viewer(viewer, ignore_nothing=true)
    if isnothing(viewer)
        vv(data, viewer; gamma=gamma, mode=DisplAddElement, element=element, time=time, show_phase=show_phase, keep_zero=keep_zero, name=name, title=title)
    else
        set_elements_linked(elements_linked, viewer)
        vv(data, viewer; gamma=gamma, mode=DisplAddElement, element=element, time=time, show_phase=show_phase, keep_zero=keep_zero, name=name, title=title)
    end
end

"""
vr(data, viewer=nothing; 
     gamma=nothing, element=0, time=0, 
     show_phase=true, keep_zero=false, title=nothing, elements_linked=false)

Visualizes images and arrays via a Java-based five-dimensional viewer "View5D".
The viewer is interactive and support a wide range of user actions. 
For details see https://nanoimaging.de/View5D
This is just a shorthand displacing data in an existing viewer (mode=DisplReplace) for the function `view5d`. See `view5d` for arguments description.
See documentation of `view5d` for explanation of the parameters.

`elements_linked`: determines wether all elements are linked together (no indidual scaling and same color)
"""
function vr(data, viewer=nothing; gamma=nothing, element=0, time=0, show_phase=false, keep_zero=false, name=nothing, title=nothing, elements_linked=false)
viewer = get_viewer(viewer, ignore_nothing=true)
if isnothing(viewer)
    vv(data, viewer; gamma=gamma, mode=DisplNew, element=element, time=time, show_phase=show_phase, keep_zero=keep_zero, name=name, title=title)
else
    vv(data, viewer; gamma=gamma, mode=DisplReplace, element=element, time=time, show_phase=show_phase, keep_zero=keep_zero, name=name, title=title)
end
end


"""
vt(data, viewer=nothing; 
     gamma=nothing, element=0, time=0, 
     show_phase=true, keep_zero=false, title=nothing, times_linked=false)

Visualizes images and arrays via a Java-based five-dimensional viewer "View5D".
The viewer is interactive and support a wide range of user actions. 
For details see https://nanoimaging.de/View5D
This is just a shorthand adding an new time point to an existing viewer (mode=DisplAddTime) for the function `view5d`. See `view5d` for arguments description.
See documentation of `view5d` for explanation of the parameters.

`times_linked`: determines wether all time points are linked together (no indidual scaling)
##Example:
```jldoctest
julia> clear_active(); for iter in 1:10 vt(rand(5,5,4,3,1), name="Iteration \$(iter)") end
created data 3

```
"""
function vt(data, viewer=nothing; gamma=nothing, element=0, time=0, show_phase=false, keep_zero=false, name=nothing, title=nothing, times_linked=false)
viewer = get_viewer(viewer, ignore_nothing=true);
viewer = vv(data, viewer; gamma=gamma, mode=DisplAddTime, element=element, time=time, show_phase=show_phase, keep_zero=keep_zero, name=name, title=title)
if !isnothing(viewer)
    set_times_linked(times_linked, viewer)
end
end

"""
vep(data, viewer=nothing; 
     gamma=nothing, element=0, time=0, 
     show_phase=true, keep_zero=false, title=nothing)

Visualizes images and arrays via a Java-based five-dimensional viewer "View5D".
The viewer is interactive and support a wide range of user actions. 
For details see https://nanoimaging.de/View5D
This is just a shorthand (with `show_phase=true`) adding an element to an existing viewer (mode=DisplAddElement) for the function `view5d`. See `view5d` for arguments description.
See documentation of `view5d` for explanation of the parameters.
"""
function vep(data, viewer=nothing; gamma=nothing, element=0, time=0, show_phase=true, keep_zero=false, name=nothing, title=nothing)
ve(data, viewer; gamma=gamma, element=element, time=time, show_phase=show_phase, keep_zero=keep_zero, name=name, title=title)
end

"""
vtp(data, viewer=nothing; 
     gamma=nothing, element=0, time=0, 
     show_phase=true, keep_zero=false, title=nothing)

Visualizes images and arrays via a Java-based five-dimensional viewer "View5D".
The viewer is interactive and support a wide range of user actions. 
For details see https://nanoimaging.de/View5D
This is just a shorthand (with `show_phase=true`) adding a time point to an existing viewer (mode=DisplAddTime) for the function `view5d`. See `view5d` for arguments description.
See documentation of `view5d` for explanation of the parameters.
"""
function vtp(data, viewer=nothing; gamma=nothing, element=0, time=0, show_phase=true, keep_zero=false, name=nothing, title=nothing)
vt(data, viewer; gamma=gamma, element=element, time=time, show_phase=show_phase, keep_zero=keep_zero, name=name, title=title)
end

"""
vrp(data, viewer=nothing; 
     gamma=nothing, element=0, time=0, 
     show_phase=true, keep_zero=false, title=nothing)

Visualizes images and arrays via a Java-based five-dimensional viewer "View5D".
The viewer is interactive and support a wide range of user actions. 
For details see https://nanoimaging.de/View5D
This is just a shorthand (with `show_phase=true`) replacing data in an existing viewer (mode=DisplReplace) for the function `view5d`. See `view5d` for arguments description.
See documentation of `view5d` for explanation of the parameters.
"""
function vrp(data, viewer=nothing; gamma=nothing, element=0, time=0, show_phase=true, keep_zero=false, name=nothing, title=nothing)
vr(data, viewer; gamma=gamma, element=element, time=time, show_phase=show_phase, keep_zero=keep_zero, name=name, title=title)
end


## just a non-exported helper function to be used in the various macros below
function do_start(exs; mystarter=vv)
blk = Expr(:block)
alt_name=nothing
viewer=nothing  # by default the active viewer is used
value = ""
for ex in exs
    varname = sprint(Base.show_unquoted, ex);
    if isnothing(alt_name)            
        name = :(begin local value=display_array($(esc(ex)),$(esc(varname)),$(mystarter),$(esc(viewer))) end)
    else
        name = :(begin local value=display_array($(esc(ex)),$(esc(alt_name)),$(mystarter),$(esc(viewer))) end)
    end
    push!(blk.args, name)

    if typeof(ex)==String
        alt_name = ex  # define this alt_name for the next round. It will generate the expression "alt_name = nothing" which has no effect.
    else 
        alt_name = nothing
        if typeof(ex) == Symbol # && typeof(eval(ex)) == JavaCall.JavaObject{Symbol("view5d.View5D")}
            viewer=ex;  # if a viewer is provided as argument, it will be used for display in the next (and future) rounds.
        end
    end

end
isempty(exs) || push!(blk.args, :value); # the second part ensures that the result of the display is the viewer
return blk; # blk
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

julia> using Unitful, AxisArrays; @vv AxisArray(rand(10,11,12,3,4),(:x,:y,:z,:liftetime, :time),(0.1u"µm",0.2u"m",0.3u"µm",1.0u"ns",2.0u"s")) # for data with axes units and names

```
"""
macro vv(exs...)
    do_start(exs; mystarter=vv);
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
a conveniance macro in its usage similar to `@show`, displaying several arrays in a joined viewer or adding to an alraedy existing viewer as new time points. 
The expression typically also constitutes the name of the displayed data in the viewer.
A string in this list of expressions in front of an array is interpreted as a replacement for the name.
Note that variables of String type or expressions in strings do currently not work. 
```
"""
macro vt(exs...)
    do_start(exs; mystarter=vt)
end

"""
@vr expressions
a conveniance macro in its usage similar to `@show`, replacing the first element with new data. 
The expression typically also constitutes the name of the displayed data in the viewer.
A string in this list of expressions in front of an array is interpreted as a replacement for the name.
Note that variables of String type or expressions in strings do currently not work. 
```
"""
macro vr(exs...)
    do_start(exs; mystarter=vr)
end

macro vep(exs...)
    do_start(exs; mystarter=vep)
end

macro vtp(exs...)
    do_start(exs; mystarter=vtp)
end

macro vrp(exs...)
    do_start(exs; mystarter=vrp)
end

#=  Missing implementations from Java:
ImportMarkers = javabridge.make_method("ImportMarkers","([[F)V")
=#
