# Run the probabilistic inundation calculations
Rscript probabilistic_inundation.R ptha18_tonga_MSL0 3
Rscript probabilistic_inundation.R ptha18_tonga_MSL0 4
Rscript probabilistic_inundation.R ptha18_tonga_MSL0 5
Rscript probabilistic_inundation.R ptha18_tonga_MSL0 6
Rscript probabilistic_inundation.R ptha18_tonga_MSL0 7

## Reduced resolution
Rscript probabilistic_inundation.R ptha18_tonga_MSL0_meshrefine2 3
Rscript probabilistic_inundation.R ptha18_tonga_MSL0_meshrefine2 4
Rscript probabilistic_inundation.R ptha18_tonga_MSL0_meshrefine2 5
Rscript probabilistic_inundation.R ptha18_tonga_MSL0_meshrefine2 6
Rscript probabilistic_inundation.R ptha18_tonga_MSL0_meshrefine2 7

# Higher sea-level
Rscript probabilistic_inundation.R ptha18_tonga_MSL0.8 3
Rscript probabilistic_inundation.R ptha18_tonga_MSL0.8 4
Rscript probabilistic_inundation.R ptha18_tonga_MSL0.8 5
Rscript probabilistic_inundation.R ptha18_tonga_MSL0.8 6
Rscript probabilistic_inundation.R ptha18_tonga_MSL0.8 7

# Site-specific curves at gauges
Rscript depth_vs_exrate_at_gauge.R "parliament"
Rscript depth_vs_exrate_at_gauge.R "ptha18_point_3458.3"
