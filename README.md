## COVID-19 post-acute care modeling project

Revised: 06/12/2020

Authors: Matthew R. Maloney, Robert Checketts, and Lindsay T. Keegan

License:  This project is available under the open source MIT License (see LICENSE.TXT file)

### Description
This repository contains code for simulating post-acute care (PAC) outcomes for COVID-19 patients using hospitalization results from epidemiological projection models. This code was specifically developed using output from the Johns Hopkins University Infectious Disease Dynamics (JHU IDD) model, and this respository includes example output data from that model. To use other models, the output files from those models can either be adapted to match the format of the JHU IDD model or the scripts can be edited to take a different file type. The repository contains five scripts:

1. *pac_functions.R*: This script contains functions that are used for running the PAC simulations, conducting analysis of the PAC simulations, and creating figures. This script includes detailed comments for each function.

2. *run_post_acute_sims.R*: This script runs post-acute care simulations using results from the JHH IDD model as inputs. One PAC simulation/projection is run for every input simulation/projection. The resulting PAC simulations are saved to disk, in the *pac_results_data* folder by default.

3. *state_analysis_example.R*: This script provides an example of analysis that can be conducted using PAC simulation results and functions in *pac_functions.R*. This script loads in results from *run_post_acute_sims.R* and calculates summary statistics/projections.  Specifically, average PAC patient counts and flows with prediction intervals are produced and plotted. By default, the resulting figures are stored in *pac_figures.R*.

4. *health_system_analysis_example.R*: similar to the *state_analysis_example.R* script, except the analysis is done at the level of a hypothetical health care system. The primary difference is that the results from *run_post_acute_sims.R*, which are recorded at the geoid/county level, are weighted by user-provided market share estimates. For this example script, we use hypothetical market share estimates rather than actual University of Utah market share estimates.

5. *svg_to_png.R* The analysis scripts save figures as .svg files. This script converts all of them to .png format.

### Usage: Instructions for running post-acute care simulations

The post-acute care script requires several user-specified inputs at the top of the script. First, *hospitalization_data_folder* must be set to a directory with .parquet files from the JHU IDD model simulations. A sample data set is provided (100 JHU IDD simulations stored as individual .parquet files) in the *input_data\example_low_R0* folder included in the repository. This example data set consists of a non-representative subset used to produce projections found in the full methodology paper [1]. These data are included to allow the user to run the code "out of the box" and are not meant to represent or be used as a forecast or projection of actual cases or scenarios. Also, the *ifr_type* string must match the pattern at the start of the file names in the hospitalization data folder. For the JHU IDD model outputs we used for development, the file names began with "low_", "med_", or "high_" ; these correspond to the different infection fatality rates considered by the JHU IDD model (0.25%, 0.5%, and 1% IFR). The input data tables only include hospitalization counts over time, rather than discharges over time. Time series of hospitalization discharges (ICU and non-ICU patients) are calculated from these input tables. The "calculation of hospital discharges section" at the end of this readme file describes these input tables and reviews how discharges are calculated from their contents.

A user must also define priors for the fraction of patients who will require each PAC type (the *priors_mean_icu* and *priors_mean_icu* vectors) and an estimated length-of-stay for each PAC type (*los_icu* and *los_nonicu* vectors). Users also define the weights to be put on those priors (set to 121 and 138 by default -- see our full methodology paper for details [1]. The *observed_icu* and *observed_nonicu* vectors are for the observed number of COVID-19 discharges that have required each type of PAC. By default, we have included the discharge counts from the University of Utah Hospital as of May 27, 2020. These values can also be set to zero.

Once all of the user inputs are defined/entered, the script can be run. All computations are run on a single thread -- the simulations have not been written to run in parallel. With the 100 example .parquet files, running the script took about 1 minute on a laptop with an intel i7-7500u cpu and 16GB of RAM. 

The PAC simulation results are stored in four separate arrays: one with PAC patient counts/census for former icu hospitalizations, one with PAC patient counts for former non-icu hospitalizations, one with daily patient flows into each PAC type for former icu hospitalizations, and one for daily patient flows into each PAC type for former non-icu hospitalizations. Each of these four arrays has four dimensions:

1. geoid
2. simulation number
3. timeid (days)
4. PAC type (e.g., hh, snf, etc.)

At the end of the *run_post_acute_sims.R* script, these arrays are saved to disk as R objects (.rds file extension). By default, they are saved in the *pac_results_data* folder.

### Usage: Instructions for performing analysis using included functions

The *state_analysis_example.R* and *health_system_analysis_example.R* scripts provide examples of how to perform analysis and create figures that summarize the post-acute care simulations. A typical analysis workflow might be

* Load in an array of simulation results (i.e., .rds file output(s) from *run_post_acute_sims*) from the *pac_results_data* folder.

* Average PAC patient counts (or flows) at each day in the projection period over all simulations using the *summarize_pac_sims* function. The first argument will be the array that loaded in the previous step. The output of the *pac_results_data* function is a data frame with rows equal to the number of time periods in the simulation times the number of post-acute care types. The columns of the data frame include the timeid (date), the care type, the expected value of patient counts or flows (mean), the median, and the upper and lower bounds of a 95\% prediction interval. 

* Plot the PAC projections using the *pac_plot_fcn* or *pac_plot_fcn2* (two different styles). See the example scripts and *pac_functions.R* script for more information.

### Calculation of hospital discharges

The function *get_discharges* is used to calculate hospital discharges (both ICU and non-ICU). It assumes the data inputs match the structure of the JHU IDD model. The needed inputs for the function include the hospitalization parquet files. Within a parquet file it is assumed that there will be the following columns:

* hosp_curr: COVID-19 patient census at the end of day. This is inclusive of ICU and non-ICU. This includes incidH.
* incidH: New COVID-19 patients. This is inclusive of ICU and non-ICU COVID-19 patients.
* icu_curr: COVID-19 ICU patient census at the end of day. This includes incidICU.
* incidICU: New COVID-19 ICU patients.
* geoid: Geo location ID (state-county level).
* time: Date.
* sim_num: Simulation ID.

Discharges are calculated as follows:

(hospital discharges) = (previous day hosp_curr) + (given day hospital covid-19 admits) - (given day hospital covid-19 census)
(icu_discharges) = (previous day hospital covid-19 census) + (given day hospital covid-19 admits) - (given day hospital covid-19 census)
(non_icu_discharges) = (hospital discharges) - (icu_discharges)

The output returns the date, geoid, sim_num, icu_discharge, non_icu_discharge, hosp_curr.

------------------------------
1. Maloney, M., Morley, R., Checketts, R., Weir, P., Barfuss, D., Meredith, H.R., Hofmann, M., Samore, M.H., Keegan, L.T. (2020). Planning for the aftershocks: a model of post-acute care needs for hospitalized COVID-19 patients. Working paper
