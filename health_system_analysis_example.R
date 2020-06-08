
library(dplyr) # for manipulating data
library(ggplot2) # for visualizations

# folders
pac_data_folder <- './/pac_results_data'
figures_folder <- './/pac_figures'

# scenario name
ifr_type <- 'high'
scen_descript <- '_southwest_CurrentUtah'
scen_name <- paste0(ifr_type,'_IFR',scen_descript)

# full names for post-acute care services
full_ct_names <- c('none' = 'Direct to home',
                   'hh' = 'Home health',
                   'snf' = 'SNF',
                   'hos' = 'Hospice')

# provide geoids and corresponding market share estimates 
hs_geoids <- c('49043','49035','49049')
hs_market_share <- c(0.7,0.5,0.2)

#import data and functions
simArr_icu <- readRDS(paste0(pac_data_folder,'//', scen_name, '_pac_results_icu.rds'))
simArr_nonicu <- readRDS(paste0(pac_data_folder,'//', scen_name, '_pac_results_nonicu.rds'))
simArr_icu_inflow <- readRDS(paste0(pac_data_folder,'//', scen_name, '_pac_results_icu_inflow.rds'))
simArr_nonicu_inflow <- readRDS(paste0(pac_data_folder,'//', scen_name, '_pac_results_nonicu_inflow.rds'))

source('.//pac_functions.R')

# calculate simulation summary stats----------------------------------------------------------------

# summarize pac patient counts/census
# ************************************
# calculate summary stats for for former icu patient pac (counts)
pac_HS_icu <- summarize_pac_sims(sim_results = simArr_icu,
                                 geoids = hs_geoids,
                                 multiplier = rep(1,length(hs_geoids)))

# calculate summary stats for former non-icu patients (counts)
pac_HS_nonicu <- summarize_pac_sims(sim_results = simArr_nonicu,
                                    geoids = hs_geoids,
                                    multiplier = rep(1,length(hs_geoids)))

# calculate summary stats for all former hospitalized patients (counts)
pac_HS_all <- summarize_pac_sims(sim_results = simArr_nonicu+simArr_icu,
                                 geoids = hs_geoids,
                                 multiplier = rep(1,length(hs_geoids)))

# summarize flows to pac 
# ************************************

# calculate summary stats for all former hospitalized patients (flows)
pac_HS_all_inflow <- summarize_pac_sims(simArr_nonicu_inflow+simArr_icu_inflow,
                                        geoids = hs_geoids,
                                        multiplier = rep(1,length(hs_geoids)))


# create figures -------------------------------------------------------------------

# a few figure examples

# patient counts
# ************************************

#all patient counts (consolidated into single plot using pac_plot_fcn)
p <- pac_plot_fcn(pac_HS_all, 
                  titleText = 'Post-acute care census',
                  subtitleText = 'Former Health System X Hospitalizations',
                  full_names = full_ct_names)
plot_save_function(p, figures_folder, fileStr = 'Health_System_X_census')
p

#all patient counts (as separate plots in a row using pac_plot_fcn2)
p <- pac_plot_fcn2(pac_HS_all, 
                   titleText = 'Post-acute care census',
                   subtitleText = 'Former Health System X Hospitalizations',
                   full_names = full_ct_names)
plot_save_function(p, figures_folder, fileStr = 'Health_System_X_census2', width = 8)
p


# former icu patient counts
p <- pac_plot_fcn2(pac_HS_icu, 
                   titleText = 'Post-acute care census, former non-ICU patients',
                   subtitleText = 'Health System X', 
                   full_names = full_ct_names)
plot_save_function(p, figures_folder, fileStr = 'Health_System_X_census_nonicu2')
p

# former non-icu patient counts
p <- pac_plot_fcn2(pac_HS_nonicu, 
                   titleText = 'Post-acute care census, former non-ICU patients',
                   subtitleText = 'Health System X', 
                   full_names = full_ct_names)
plot_save_function(p, figures_folder, fileStr = 'Health_System_X_census_nonicu2')
p


# patient flows
# ************************************

#all patient flows
p <- pac_plot_fcn2(pac_HS_all_inflow, 
                   titleText = 'Post-acute care flows per day, all patients',
                   subtitleText = 'Health System X', 
                   full_names = full_ct_names)
plot_save_function(p, figures_folder, fileStr = 'Health_System_X_flows_all2')
p

