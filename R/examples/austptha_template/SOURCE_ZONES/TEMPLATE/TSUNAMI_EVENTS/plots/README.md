# Code to compare observed events with model scenarios on a single source-zone.

These notes provide some details on the code used to compare model scenarios and observations on a single source-zone. 

Codes in this folder can be run after executing codes in the parent directory (as described [here](../README.md)). They can only be run on source-zones for which DART test data exists. Before running these scripts, the source-zone specific script corresponding to [../check_dart_example.R](../check_dart_example.R) should have been run (see [here](../../../dart_check_codes) for source-zone-specific DART-buoy scripts and further explanation).

## Getting the resulting files 

The files produced by running [gauge_summary_statistics.R](gauge_summary_statistics.R) are often used in subsequent analysis - for instance, the corresponding file paths in the original analysis are stored [here](../../../../EVENT_RATES/config_DART_test_files.R) and are used to examine the statistical properties of random tsunamis [here](../../../../EVENT_RATES/stage_range_summary.R) and [here](../../../../EVENT_RATES/event_properties_and_GOF.R) and [here](../../../../EVENT_RATES/event_dart_coverage_vs_distance.R) ). These output files can also be downloaded from the NCI THREDDS server at the following locations: [kermadectonga2](http://dap.nci.org.au/thredds/remoteCatalogService?catalog=http://dapds00.nci.org.au/thredds/catalog/fj6/PTHA/AustPTHA_1/SOURCE_ZONES/kermadectonga2/TSUNAMI_EVENTS/plots/catalog.xml),
[kurilsjapan](http://dap.nci.org.au/thredds/remoteCatalogService?catalog=http://dapds00.nci.org.au/thredds/catalog/fj6/PTHA/AustPTHA_1/SOURCE_ZONES/kurilsjapan/TSUNAMI_EVENTS/plots/catalog.xml), 
[newhebrides2](http://dap.nci.org.au/thredds/remoteCatalogService?catalog=http://dapds00.nci.org.au/thredds/catalog/fj6/PTHA/AustPTHA_1/SOURCE_ZONES/newhebrides2/TSUNAMI_EVENTS/plots/catalog.xml), 
[puysegur2](http://dap.nci.org.au/thredds/remoteCatalogService?catalog=http://dapds00.nci.org.au/thredds/catalog/fj6/PTHA/AustPTHA_1/SOURCE_ZONES/puysegur2/TSUNAMI_EVENTS/plots/catalog.xml), 
[solomon2](http://dap.nci.org.au/thredds/remoteCatalogService?catalog=http://dapds00.nci.org.au/thredds/catalog/fj6/PTHA/AustPTHA_1/SOURCE_ZONES/solomon2/TSUNAMI_EVENTS/plots/catalog.xml), 
[southamerica](http://dap.nci.org.au/thredds/remoteCatalogService?catalog=http://dapds00.nci.org.au/thredds/catalog/fj6/PTHA/AustPTHA_1/SOURCE_ZONES/southamerica/TSUNAMI_EVENTS/plots/catalog.xml), and
[sunda2](http://dap.nci.org.au/thredds/remoteCatalogService?catalog=http://dapds00.nci.org.au/thredds/catalog/fj6/PTHA/AustPTHA_1/SOURCE_ZONES/sunda2/TSUNAMI_EVENTS/plots/catalog.xml).



## A note on the file/folder structure when the PTHA18 scripts were run

[As stated earlier](https://github.com/GeoscienceAustralia/ptha/tree/master/R/examples/austptha_template/SOURCE_ZONES), when the PTHA18 was run the folder [../../../../SOURCE_ZONES](../../../../SOURCE_ZONES) contained one folder per source zone, [just like the data available on NCI THREDDS here](http://dap.nci.org.au/thredds/remoteCatalogService?catalog=http://dapds00.nci.org.au/thredds/catalog/fj6/PTHA/AustPTHA_1/SOURCE_ZONES/catalog.xml). Inside each source-zone folder were the scripts from the [../../../TEMPLATE](../../../TEMPLATE) directory, as well as the resulting datasets. The scripts were identical **except** for those used to compare the results with DART buoys for specific events, which are provided with some discussion [here](../../../dart_check-codes). 

# Usage

Once the `../check_dart_SOURCE_ZONE_NAME_HERE.R` code has been run, the script [gauge_summary_statistics.R](./gauge_summary_statistics.R) is used to do some processing on a set of PTHA18 scenarios having similar location and magnitude and the observations. Please note the script does not account for any earthquake-rate information, and it does not attempt to exclude scenarios that are impossible according to the PTHA18 (e.g. based on peak-slip limits). 

The script can be run from the commandline like:

    Rscript gauge_summary_statistics.R

and may optionally be followed by a plotting script:

    Rscript event_plot.R 5 7.5

## Details of event_plot.R

The [event_plot.R](event_plot.R) script is simple so is described first. It creates model-vs-data time-series plots for scenarios processed by [gauge_summary_statistics.R](gauge_summary_statistics.R). The first numeric argument (e.g. 5) gives the number of hours after tsunami arrival to plot at each DART. The second numeric argument (e.g. 7.5) will exclude scenarios that have peak-slip greater than 7.5 times the mean-scaling-relation-slip inferred from the magnitude. See Section 3.2.3 in the [PTHA18 Report]() for discussion of peak-slip limits, which explains why PTHA18 uses the 7.5 factor. In reality there is much uncertainty around this limit, because slip-maxima are a poorly resolved aspect of earthquake-slip inversions. 

## Details of gauge_summary_statistics.R

The [gauge_summary_statistics.R](gauge_summary_statistics.R) script reads all the tsunami scenarios having "similar earthquake location and magnitude" as the observed event, which were actually selected via the `../check_dart_SOURCE_ZONE_NAME_HERE.R` script [discussed here](../../../dart_check-codes). It then extracts the time-series in a convenient form, performs some analyses, and makes some plots. The script saves its own workspace, separately for each tsunami event and each rigidity model. This permits access to all the variables defined by [gauge_summary_statistics.R](./gauge_summary_statistics.R) for each case, by loading the relevant file. PTHA18 analyses repeatedly make use of this.

Beware [gauge_summary_statistics.R](gauge_summary_statistics.R) does not give any consideration of the earthquake rates (which are computed later in [../../../../EVENT_RATES](../../../../EVENT_RATES)). Also, it does not exclude scenarios that are "impossible" according to the peak-slip limits in PTHA18. Such scenarios are excluded in later processing (example - the script [stage_range_summary.R](../../../../EVENT_RATES/stage_range_summary.R) does this around lines 101-116 -- and you will see similar exclusions in other scripts). 

### Structure of output files 

Next we give a more concrete example of the output file structure using the `kurilsjapan` source-zone as an example. On the `kurilsjapan` source-zone we had two test events (both defined in [check_dart_kurilsjapan.R](../../../dart_check_codes/check_dart_kurilsjapan.R)). This means [gauge_summary_statistics.R](gauge_summary_statistics.R) produces 4 different R-workspace files that are [available here](http://dap.nci.org.au/thredds/remoteCatalogService?catalog=http://dapds00.nci.org.au/thredds/catalog/fj6/PTHA/AustPTHA_1/SOURCE_ZONES/kurilsjapan/TSUNAMI_EVENTS/plots/catalog.xml) - two files per event, with constant and depth-varying rigidity respectively. The latter are distinguished by having `varyMu` in the filname. On other source-zones that have DART test data, there are analogous files, including on [kermadectonga2](http://dap.nci.org.au/thredds/remoteCatalogService?catalog=http://dapds00.nci.org.au/thredds/catalog/fj6/PTHA/AustPTHA_1/SOURCE_ZONES/kermadectonga2/TSUNAMI_EVENTS/plots/catalog.xml),
[kurilsjapan](http://dap.nci.org.au/thredds/remoteCatalogService?catalog=http://dapds00.nci.org.au/thredds/catalog/fj6/PTHA/AustPTHA_1/SOURCE_ZONES/kurilsjapan/TSUNAMI_EVENTS/plots/catalog.xml), 
[newhebrides2](http://dap.nci.org.au/thredds/remoteCatalogService?catalog=http://dapds00.nci.org.au/thredds/catalog/fj6/PTHA/AustPTHA_1/SOURCE_ZONES/newhebrides2/TSUNAMI_EVENTS/plots/catalog.xml), 
[puysegur2](http://dap.nci.org.au/thredds/remoteCatalogService?catalog=http://dapds00.nci.org.au/thredds/catalog/fj6/PTHA/AustPTHA_1/SOURCE_ZONES/puysegur2/TSUNAMI_EVENTS/plots/catalog.xml), 
[solomon2](http://dap.nci.org.au/thredds/remoteCatalogService?catalog=http://dapds00.nci.org.au/thredds/catalog/fj6/PTHA/AustPTHA_1/SOURCE_ZONES/solomon2/TSUNAMI_EVENTS/plots/catalog.xml), 
[southamerica](http://dap.nci.org.au/thredds/remoteCatalogService?catalog=http://dapds00.nci.org.au/thredds/catalog/fj6/PTHA/AustPTHA_1/SOURCE_ZONES/southamerica/TSUNAMI_EVENTS/plots/catalog.xml), and
[sunda2](http://dap.nci.org.au/thredds/remoteCatalogService?catalog=http://dapds00.nci.org.au/thredds/catalog/fj6/PTHA/AustPTHA_1/SOURCE_ZONES/sunda2/TSUNAMI_EVENTS/plots/catalog.xml).


Going back to the `kurilsjapan` example: if we download any of the `*.Rdata` files [from this directory](http://dap.nci.org.au/thredds/remoteCatalogService?catalog=http://dapds00.nci.org.au/thredds/catalog/fj6/PTHA/AustPTHA_1/SOURCE_ZONES/kurilsjapan/TSUNAMI_EVENTS/plots/catalog.xml) (say `gauge_summary_stats_session_kurilsjapan_tohoku_2011_03_11_Mw9.1.Rdata`), then it can be loaded from within R using:
    
    # Here we just pick on file for an example
    load('./gauge_summary_stats_session_kurilsjapan_tohoku_2011_03_11_Mw9.1.Rdata')

and you can see that many variables have been defined (use the `ls()` command to show all variables in the workspace). The variables correspond to those created by [gauge_summary_statistics.R](./gauge_summary_statistics.R). 

For comparing the modelled and observed tsunami, the uniform-slip model results are in `uniform_slip_stats`, the variable-area-uniform-slip model results are in `variable_uniform_slip_stats`, and the heterogeneous-slip model results are in `stochastic_slip_stats`. These variables are two-dimensional lists, with the first dimension corresponding to the DART buoy (check e.g. `names(stochastic_slip_stats)` to see this), and the second dimension corresponding to the model scenario. For example, to get the 10th scenario at the 2nd dart buoy for the heterogeneous-slip model, we would need to look inside `stochastic_slip_stats[[2]][[10]]`. 

The latter is itself a list, containing a bunch of variables (`names(stochastic_slip_stats[[2]][[10]])`). These including the observed time-series (`data_t` and `data_s` giving the times and stage-residuals respectively, over a time-period which focusses on the first few hours of tsunami when high-frequency measurements exist), the modelled time-series (`model_t` and `model_s`, limited to similar times as the data), and some other statistics. Beware that the goodness-of-fit type statistic is computed over a possibly shorter time-interval. Please look carefully at the function `plot_model_gauge_vs_data_gauge` inside [gauge_summary_statistics.R](./gauge_summary_statistics.R) to understand what everything is. 