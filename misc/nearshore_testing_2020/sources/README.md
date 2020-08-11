# How to download a version of this folder with all the source-inversions
-------------------------------------------------------------------------

A compressed version of these files has been posted to the NCI THREDDS Server here: http://dapds00.nci.org.au/thredds/fileServer/fj6/PTHA/Nearshore_testing_2020/sources.zip

The above link also contains some data that is needed to create the rasters and plots, but is too large to place in this repository. However we keep the codes + basic data here.

Below is the regular documentation.

# Earthquake source inversions
------------------------------

The directories here contain code and data to create vertical deformation
rasters from published earthquake source inversions, and (in most cases) smooth
the result with a Kajuira filter.

# How to run it

## Step 0: Install R and the rptha package

Follow the instructions [here](https://github.com/GeoscienceAustralia/ptha/tree/master/R)

## Step 1: Compute the unfiltered vertical deformation from the earthquake-source-inversion data

To create the un-filtered vertical deformation rasters, use `Rscript` to run each of the following codes
(called from inside their own directory).

```
    Chile1960/FujiSatake2013/Okada_vertical_component.R  
    Chile1960/HoEtAl2019/reconstruct_free_surface.R      

    Chile2010/FujiSatake2013/Okada_vertical_component.R  
    Chile2010/LoritoEtAl2011/Okada_vertical_component.R  

    Chile2015/RomanoEtAl2016/convert_for_TFD.R           
    Chile2015/WilliamsonEtAl2017/Okada_vertical_deformation.R

    Sumatra2004/FujiSatake2007/Okada_vertical_component.R
    Sumatra2004/LoritoEtAl2010/Okada_vertical_component.R
    Sumatra2004/PiatanesiLorito2007/Okada_vertical_component.R

    Tohoku2011/SatakeEtAl2013/Okada_vertical_component.R
    Tohoku2011/YamakaziEtAl2018/Okada_vertical_component.R
    (not required for Tohoku2011/RomanoEtAl2015)
```

For example, to run the file `Chile1960/FujiSatake2013/Okada_vertical_component.R`, start a terminal and do:

```
    # Move into the directory
    cd Chile1960/FujiSatake2013/
    # Run the script -- requires that rptha is installed.
    Rscript Okada_vertical_component.R
```

This will create a number of output files, including a file containing the
vertical deformation `Fuji_chile1960_sources_SUM.tif`. 

For other inversions that have a `Okada_vertical_component.R` script, analogous files are created. In some other cases different approaches apply (i.e. some inversions do not have a `Okada_vertical_component.R` script). Thoses cases are:
* Chile1960/HoEtAl2019/  - the script makes a linear combination of gaussian free-surface perturbations.
* Chile2015/RomanoEtAl2016/ - this inversions uses triangular elements, and relies on an associated TFD code provided by Fabrizio Romano (not currently included herein -- but if that is installed, then the provided script can produce the deformation raster).
* Tohoku2011/RomanoEtAl2015 - this inversion is a sum of unit-sources derived from a 3D finite-element model. In this case only the raster is provided.

## Step 2: Apply Kajiura filter to the vertical deformations (in most cases)

Once all the rasters have been created, the script `apply_kajiura_to_rasters.R` can be run
to apply a Kajiura filter to most of the rasters. 

This is not applicable for Chile1960/HoEtAl2019, which is already a
water-surface deformation - so that is skipped.
