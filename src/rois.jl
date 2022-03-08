using Serialization
export get_rois

"""
    get_rois(data; overwrite=false,  confirm_selected=true, do_save=true, coord_filename="selected_coordinates.txt", roi_size=(16,16))

extracts regions of interest using View5D. The centers of the rois are selected by user interaction (pressing 'm' at each location).
The user interaction is saved in a file `coord_filename` and reloaded automatically if the function is called again.
#arguments
+ `data` : data to extract the regions of interest from
+ `overwrite`: boolean flag indicating weather a pre-existing file should be loaded or overwritten.
+ `coord_filename`: filname where to save the user-interaction to
+ `roi_size` : size of the region of interest to extract
+ `do_save`:   boolean defining whether to serialize the user interaction to disk
+ `confirm_selected`: if true, a prompt waits for user interaction finished.
"""
function get_rois(data; viewer=nothing, overwrite=false, confirm_selected=true, do_save=true, coord_filename="selected_coordinates.coords", roi_size=(16,16))
    bp = []
    try
        bp = deserialize(coord_filename)
    catch
    end
    if overwrite || isempty(bp)
        v = let 
            if isnothing(viewer)
                v = view5d(data)
            else
                viewer
            end
        end
        if confirm_selected
            println("Please select all beads by using the keys `m`, `0`, `9`,`M`. Press enter when ready.")
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
    println("$(length(bp)) beads evaluated.")
    rois = []
    for n in 1:length(bp)
        pos = Tuple(round.(Int,bp[n]).+1)
        push!(rois, select_region(data, center=pos, new_size=roi_size))
    end
    return rois
end
