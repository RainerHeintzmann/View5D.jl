using Serialization
export get_positions, get_rois, calibrate_pixelsize

"""
    get_positions(data; positions=nothing, viewer=nothing, overwrite=false, confirm_selected=true, do_save=true, coord_filename="selected_coordinates.coords")
    determines a number of positions using View5D. The positions are selected by user interaction (pressing 'm' at each location).
    The user interaction is saved in a file `coord_filename` and reloaded automatically if the function is called again.
    
    #arguments
    + `data` : data to extract the regions of interest from
    + `overwrite`: boolean flag indicating weather a pre-existing file should be loaded or overwritten.
    + `coord_filename`: filname where to save the user-interaction to
    + `do_save`:   boolean defining whether to serialize the user interaction to disk
    + `confirm_selected`: if true, a prompt waits for user interaction finished.
    
    #returns
    a tuple of the selected positions which can be resupplied via the `positions` argument
"""
function get_positions(data; positions=nothing, viewer=nothing, overwrite=false, confirm_selected=true, do_save=true, coord_filename="selected_coordinates.coords")
    bp = positions
    if isnothing(bp)
        try
            bp = deserialize(coord_filename)
        catch
        end
    if overwrite || isnothing(bp) || isempty(bp)
        v = let 
            if isnothing(viewer)
                v = view5d(data)
            else
                viewer
            end
        end
        if confirm_selected
            println("Please select all positions by using the keys `m`, `0`, `9`,`M`. Press enter when ready.")
            q = readline()
        end
        bead_pos = export_marker_lists(v);
        if ndims(data) > 2
            bp = [bead_pos[i][3:5] for i in 1:length(bead_pos)]
        else
            bp = [bead_pos[i][3:4] for i in 1:length(bead_pos)]
        end
        if do_save
            serialize(coord_filename, bp) 
        end
    end
    end
    return [p .+ 1 for p in bp]
end

"""
    get_rois(data; overwrite=false,  confirm_selected=true, do_save=true, coord_filename="selected_coordinates.txt", roi_size=(16,16))

extracts regions of interest using View5D. The centers of the rois are selected by user interaction (pressing 'm' at each location).
The user interaction is saved in a file `coord_filename` and reloaded automatically if the function is called again.

#arguments
+ `data` : data to extract the regions of interest from
+ `positions`: if supplied, the positions are used instead of selecting them interactively
+ `viewer`: a pre-existing viewer to use for the user interaction
+ `overwrite`: boolean flag indicating weather a pre-existing file should be loaded or overwritten.
+ `coord_filename`: filname where to save the user-interaction to
+ `roi_size` : size of the region of interest to extract
+ `do_save`:   boolean defining whether to serialize the user interaction to disk
+ `confirm_selected`: if true, a prompt waits for user interaction finished.
+ `verbose`: if true, the number of selected ROIs is printed

#returns
a tuple of the extracted ROIs and the selected positions
The latter can be resupplied via the `positions` argument
"""
function get_rois(data; positions=nothing, viewer=nothing, overwrite=false, confirm_selected=true, do_save=true, coord_filename="selected_coordinates.coords", roi_size=(16,16), verbose=false)
    bp = get_positions(data; positions=positions, viewer=viewer, overwrite=overwrite, confirm_selected=confirm_selected, do_save=do_save, coord_filename=coord_filename)
    if verbose
        println("$(length(bp)) ROIs selected.")
    end
    rois = []
    for n in 1:length(bp)
        pos = Tuple(round.(Int,bp[n]))
        push!(rois, select_region(data, center=pos, new_size=roi_size))
    end
    return rois, bp
end


"""
    calibrate_pixelsize(data,sigma=2.0; norm_distance=10, norm_unit="µm", viewer=nothing, overwrite=false, confirm_selected=true, do_save=true, coord_filename="selected_bar_coordinates.coords")

calibrates the pixelsize using a measured calibration image.
#arguments
+ `data` : calibration image
+ `norm_distance` : this is the distance to mark in the calibration image. X and Y are currently assumed to mark the same distance
+ `norm_unit` : units of the distance to mark in the calibration image. X and Y are currently assumed to mark the same distance
+ `overwrite`: boolean flag indicating weather a pre-existing file should be loaded or overwritten.
+ `coord_filename`: filname where to save the user-interaction to
+ `do_save`:   boolean defining whether to serialize the user interaction to disk
+ `confirm_selected`: if true, a prompt waits for user interaction finished.
"""
function calibrate_pixelsize(data; norm_distance=10, norm_unit="µm", viewer=nothing, overwrite=false, confirm_selected=true, do_save=true, coord_filename="selected_bar_coordinates.coords")
    positions = []
    try
        positions = deserialize(coord_filename)
    catch
    end
    if overwrite || isempty(positions)
        v = let 
            if isnothing(viewer)
                v = view5d(data)
            else
                viewer
            end
        end
        if confirm_selected
            println("Please mark vie `m consecutively positions x1,x2, y1,y2,  with mutual distances of $(norm_distance)$(norm_unit).\nPress enter when ready.")
            q = readline()
        end
        positions = export_marker_lists(v);
        if length(positions)  != 4
            error("the number of selected positions does not agree to the required format x1,x2,y1,y2")
            return (0.0,0.0)
        end
        if do_save
            serialize(coord_filename, positions) 
        end
    end
    # @show positions
    dx = norm_distance ./ sqrt.(sum(abs2.(positions[2][3:4] .- positions[1][3:4])))
    dy = norm_distance ./ sqrt.(sum(abs2.(positions[4][3:4] .- positions[3][3:4])))
    return (dx,dy)
end
