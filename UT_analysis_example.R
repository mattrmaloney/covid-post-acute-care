
library(dplyr) # for manipulating data
library(ggplot2) # for visualizations

# folders
pac_data_folder <- './/pac_results_data'
figures_folder <- './/pac_figures'

# scenario name
ifr_type <- 'med'
scen_descript <- '_southwest_CurrentUtah'
scen_name <- paste0(ifr_type,'_IFR',scen_descript)

# full names for post-acute care services
full_ct_names <- c('none' = 'Direct to home',
                   'hh' = 'Home health',
                   'snf' = 'SNF',
                   'hos' = 'Hospice')

#import data and functions
simArr_icu <- readRDS(paste0(pac_data_folder,'//', scen_name, '_pac_results_icu.rds'))
simArr_nonicu <- readRDS(paste0(pac_data_folder,'//', scen_name, '_pac_results_nonicu.rds'))
simArr_icu_inflow <- readRDS(paste0(pac_data_folder,'//', scen_name, '_pac_results_icu_inflow.rds'))
simArr_nonicu_inflow <- readRDS(paste0(pac_data_folder,'//', scen_name, '_pac_results_nonicu_inflow.rds'))

source('.//pac_functions.R')
  
# calculate simulation summary stats----------------------------------------------------------------

# get UT geoids
run_geoids <- dimnames(simArr_icu)[[1]]
utah_geoids <- run_geoids[grepl(pattern = "^49", x = run_geoids)]

# summarize pac patient counts/census
# ************************************
# calculate summary stats for for former icu patient pac (counts)
pac_UT_icu <- summarize_pac_sims(sim_results = simArr_icu,
                                 geoids = utah_geoids,
                                 multiplier = rep(1,length(utah_geoids)))

# calculate summary stats for former non-icu patients (counts)
pac_UT_nonicu <- summarize_pac_sims(sim_results = simArr_nonicu,
                                    geoids = utah_geoids,
                                    multiplier = rep(1,length(utah_geoids)))

# calculate summary stats for all former hospitalized patients (counts)
pac_UT_all <- summarize_pac_sims(sim_results = simArr_nonicu+simArr_icu,
                                 geoids = utah_geoids,
                                 multiplier = rep(1,length(utah_geoids)))

# summarize flows to pac 
# ************************************

# calculate summary stats for all former hospitalized patients (flows)
pac_UT_all_inflow <- summarize_pac_sims(simArr_nonicu_inflow+simArr_icu_inflow,
                                        geoids = utah_geoids,
                                        multiplier = rep(1,length(utah_geoids)))


# create figures -------------------------------------------------------------------

# a few figure examples

# patient counts
# ************************************

#all patient counts (consolidated into single plot using pac_plot_fcn)
p <- pac_plot_fcn(pac_UT_all, 
                  titleText = 'Post-acute care census',
                  subtitleText = 'State of Utah',
                  full_names = full_ct_names)
plot_save_function(p, figures_folder, fileStr = 'State_of_Utah_census')
p

#all patient counts (as separate plots in a row using pac_plot_fcn2)
p <- pac_plot_fcn2(pac_UT_all, 
                   titleText = 'Post-acute care census',
                   subtitleText = 'State of Utah',
                   full_names = full_ct_names)
plot_save_function(p, figures_folder, fileStr = 'State_of_Utah_census2', width = 8)
p


# former icu patient counts
p <- pac_plot_fcn2(pac_UT_icu, 
                   titleText = 'Post-acute care census, former ICU patients',
                   subtitleText = 'State of Utah', 
                   full_names = full_ct_names)
plot_save_function(p, figures_folder, fileStr = 'State_of_Utah_census_nonicu2')
p

# former non-icu patient counts
p <- pac_plot_fcn2(pac_UT_nonicu, 
                   titleText = 'Post-acute care census, former non-ICU patients',
                   subtitleText = 'State of Utah', 
                   full_names = full_ct_names)
plot_save_function(p, figures_folder, fileStr = 'State_of_Utah_census_nonicu2')
p


# patient flows
# ************************************

#all patient flows
p <- pac_plot_fcn2(pac_UT_all_inflow, 
                   titleText = 'Post-acute care flows per day, all patients',
                   subtitleText = 'State of Utah residents who require specialized PAC', 
                   full_names = full_ct_names)
plot_save_function(p, figures_folder, fileStr = 'State_of_Utah_flows_all2')
p

