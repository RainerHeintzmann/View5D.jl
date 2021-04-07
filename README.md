## View5D.jl  - interface to View5D, an interactive data viewer 

[View5D.jl](https://github.com/RainerHeintzmann/View5D.jl) is a Java-based viewer for up to 5-dimensional data (including complex images). It supports three mutually linked orthogonal slicing displays for XYZ coordinates, arbitrary numbers of colors (4th dimension) which can also be used to display spectral curves and a time slider for the 5th dimension.  


# Installation
Not registered yet, but you can install current state with:
```julia
julia> ] add https://github.com/RainerHeintzmann/View5D.jl
```


# Quick Overview

## Supported Datatypes
The interaction to julia is currently at a basic level of invoking the viewer using existing data. However, it already supports a wide range of data formats: `Float32`, `Float64`, `UInt8`, `Int8`, `UInt16`, `Int16`, `UInt32`, `Int32`, `Int`.
`Complex32`, `RGB` and `Gray`

## Tracking over Time
`View5D` also supports displaying and interacting with tracking in 3D over time (and other combinations) datasets.  This can come in handy for single particle or cell tracking. A particularly interesting feature is that the data can be pinned (aligned) to a chosen track. 

## Menus

`View5D` has 3 context menus (main panel, element view panel and general) with large range of ways to change the display. A system of equidistant location (and brightness) information (scaling and offset) is also present but not yet integrated into julia. 

## Complex Data
Display of `Complex`-valued data can be toggled between `magnitude`, `phase`, `real` and `imaginary` part.  A complex-valued array by default switches the viewer to a `gamma` of 0.3 easing the inspection of Fourier-transformed data. However, gamma is adjustable interactively as well as when invoking the viewer.

# Background

The Java viewer [View5D](https://nanoimaging.de/View5D) has been integrated into Julia with the help of [JavaCall.jl](https://github.com/JuliaInterop/JavaCall.jl).  Currently the viewer has its full Java functionality which includes displaying and interacting with 5D data. Generating up to three-dimensional histograms and interacting with them to select regions of interest in the 3D histogram but shown as a selection in the data. It allows selection of a gate `element` where thresholds can be applied to which have an effect on statistical evaluation (mean, max, min) in other `element`s if the `gate` is activated.
It further supports multiplicative overlay of colors. This feature is useful when processed data (e.g. local orientation information or polarization direction or ratios) needs to be presented along with brightness data. By choosing a gray-valued and a  constant brightness value-only (HSV) colormap for brightness and orientation data respectively, in multiplicative overlay mode a result is obtained that looks like the orientation information is staining the brightness. These results look often much nicer compared to gating-based display based on a brightness-gate, which is also supported.
Color display of floating-point or 16 or higher bit data supports adaptively updating colormaps.
Zooming in on a colormap,  by changing the lower and upper display threshold, for some time the colormap is simply changed to yield a smooth experience but occasionally the cached display data is recomputed to avoid loosing fine granularity on the color levels.



# List of some useful commands to interact with View5D from julia
* `view5d()`: visualizes data. Via "mode" it can be selected whether a new viewer will be used (`mode="new"`) or the data is appended to the existing viewer via the element (`mode="add_time"`) or time direction (`mode="add_time"`). Data can also be replacing currently displayed data (`mode="replace"`), which is useful to display iterative updates.
* `process_keys()`: the easiest way to remote-control the viewer by sending it key-strokes. Be careful: almost all keys have a meaning assigned and the viewer has no undo function.
* `set_display_size()`: sets the size (in pixels) this viewer occupies on the screen.
* `set_title()`: sets a new title to the viewer window.
* `to_front()`: brings the viewer to the front
* `set_gamma()`: sets the gamma display-value for a particular color channel (element)
* `set_min_max_thresh()`: sets the minimum and maximum display value for a particular color channel (element).
* `export_marker_lists()`, `import_marker_lists()`: these functions allow you to display location information such as obtained from tracking algorithms.


# Known issues
* Current problems of `View5D` are that it is not well suited to displaying huge datasets. This is due to memory usage and the display slowing down due to on-the-fly calculations of features such as averages and the like. A further problem is that it seems very difficult to free Java memory correctly upon finalization. Even though this was not tested yet, I would expect the viewer to gradually use up memory when repeatedly invoked and closed.
