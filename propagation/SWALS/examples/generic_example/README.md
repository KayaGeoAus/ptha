Here we attempt to give a fairly generic interface to a spherical coordinates
linear shallow water model.

To run it:
* Copy one of the '\*.in' files to a new file (e.g. 'my_model.in'), and edit it
to ensure that the input_elevation_raster and input_stage_raster exist on your
filesystem, and that the model extents are as desired. The input rasters should
give the initial elevation and stage in lon-lat coordinates. 
* The elevation raster should cover the desired model domain, but it can
have a larger north-east-south-west extent than the model. The
model will get the data it needs using bilinear interpolation. So for example, 
you can run a small area model using a global DEM, without editing the DEM.
Furthermore it is not essential for the model resolution to match the data
resolution.  However the model does not correct for the periodicity of
longitude when extracting raster data. For instance, if the input raster has
east-west extent [-180, 180], then the tsunami model cannot have east-west
extent like [0, 360], but it could have [-180, 180], or [-180, 12], or [-50,
100], etc. 
* The stage raster can be either smaller or larger than the desired model domain. The
model will extract stages from this raster where possible, using bilinear
interpolation. It will use a value of 0 elsewhere. 
* If the model extent covers 360 degrees of longitude (e.g. [0, 360] or [-180, 180] or [-40, 320]), 
then east-west periodic boundary conditions are used, with reflective
north-south boundaries.  In this case, the EW model boundaries should agree
exactly with the EW boundaries of the input elevation data. 
* If the model extent does not cover 360 degrees of longitudde, a transmissive
  boundary is used.

Then compile and run the model with (e.g.):

    make -B -f make_generic_model
    OMP_NUM_THREADS=6 ./generic_model my_model.in

The above code uses 6 openmp threads -- you can use any number relevant to your system.
It can also be advantageous to control the process affinity (e.g. include
"OMP_PROC_BIND=true" in the model run command), although this depends on your
hardware and what other jobs are being run.

