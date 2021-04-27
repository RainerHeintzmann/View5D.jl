using View5D, IndexFunArrays # you may need to add the package IndexFunArrays

sz = (50,50,5,10)
N = 60
offsets = 1 .+ (sz.-1) .* rand(4,N);
sigmas = 2.0 .*(0.3 .+rand(4,N));
data =  gaussian(sz,offset = offsets, weight=rand(N), sigma=sigmas);  # generates random Gaussians in 4D

@vv data  
# use "e" to advance spectral channels, "n" in the bottom right (element) panel to toggle normalization
# by "r" "g" "b" you can choose colors for elements. "v" toggles the color in and out of overlay,
# color overlay is accessed by "C" (shift-"c")

# Lets do a 2d diffusion of guassian blobs over time:

