Code template for the Australian Probabilistic Tsunami Hazard Assessment 2018
-----------------------------------------------------------------------------

This template contains codes used for the 2018 Australian PTHA. It does not contain
the actual data or model results, because these files would be very large and unsuitable 
for a git repository. However, see [this page](https://github.com/GeoscienceAustralia/ptha/tree/master/ptha_access)
for information on accessing the results.

The sub-folders below all contain relevant scripts and README information:

[DATA](DATA) is used for data that has been 'processed' or developed for modelling
  [e.g. sourcezone contours, edited DEMs, etc]. It should not contain RAW data,
  (the latter instead goes in '../../DATA/')

[SOURCE_ZONES](SOURCE_ZONES) is used for the unit source initial conditions and tsunami runs for
  every source-zone. This is the bulk of our modelling results.

[EVENT_RATES](EVENT_RATES) contains code to compute the rate of earthquakes on each source-zone,
  the tsunami wave height exceedance rates at each hazard point, etc.


The analysis proceeds by defining the geometry of one or source zones (with
SOURCEZONE_CONTOURS and SOURCEZONE_DOWNDIP_LINES), and making a DEM and hazard
points for tsunami modelling (see [DATA](DATA)). 

Next, we can make a suite of tsunami events on each source-zone, by following
the procedures in [SOURCE_ZONES](SOURCE_ZONES). This is the most time consuming
and computationally intensive part of the analysis, and super-computer access
is basically essential for multi-source analyses involving large source-zones. 

Finally, we can compute rates for each of these events, and compute various tsunami 
hazard metrics at our hazard points, using code in [EVENT_RATES](EVENT_RATES).
