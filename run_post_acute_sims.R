#Authors: Robert Checketts and Matt Maloney

#general information: this script calculates discharges and post-acute care outcomes for 
# covid patients using  hospitalization results from an epidemiology model (specifically, 
# the Johns Hopkins University Infectious Disease Dynamics (JHU IDD) model). See the repository
# readme for  more information.

# Libraries ----
library(arrow) # for loading parquet files
library(dplyr) # for manipulating data
library(ggplot2) # for visualizations
library(gtools) # dirichlet distribution
library(data.table)

#inputs -------------------------------------------------------------------------------------------

# folder location with hospitalization data
# (designed for JHH model output as series of .parquet files)
hospitalization_data_folder <- '.\\input_data\\May 18\\southwest_CurrentUtah'

# folders for storing results
results_folder <- '.\\pac_results_data'

# scenario name
ifr_type <- 'med' #this is used to pull from the correct file, must be low, med, or high
scen_descript <- '_southwest_CurrentUtah' #additional description of policy or scenario to add to output file names
scen_name <- paste0(ifr_type,'_IFR',scen_descript)

# priors for fraction of patients who require specialized post-acute care
priors_mean_icu <- c('none' = 0.488,'hh' = 0.20,'snf' = 0.30,'hos' = 0.012) 
priors_mean_nonicu <- c('none' = 0.748,'hh' = 0.18,'snf' = 0.06,'hos' = 0.012)

# post-acute care length-of-stay parameters (days)
los_icu <- c('none' = 0,'hh' = 15,'snf' = 18,'hos' = 7)
los_nonicu <- c('none' = 0,'hh' = 15,'snf' = 18,'hos' = 7)

# weight to put on post-acute care fraction priors 
prior_wt_icu <- 138
prior_wt_nonicu <- 121

# observed discharges within region/health system (used to update priors)
observed_icu <-  c('none' = 17,'hh' = 3,'snf' = 3,'hos' = 1)
observed_nonicu <-  c('none' = 45,'hh' = 4,'snf' = 3,'hos' = 2)

# Run post-acute care simulations-------------------------------------------------------------------

# load post-acute care functions
source('.//pac_functions.R')

# Get hospitalization data filenames
full_loc <- list.files(pattern = paste0(ifr_type,".*.parquet"),
                       path = hospitalization_data_folder, full.names = T)

# Run Function to load hospital discharge data
discharge_data <- lapply(X = full_loc, get_discharges)
discharge_data <- rbindlist(discharge_data)

# get parameters for posterior dirichlet distribution 
alphas_icu <- get_updated_alphas(prior_wt = prior_wt_icu,
                                 prior_means = priors_mean_icu,
                                 observations = observed_icu)
alphas_nonicu <- get_updated_alphas(prior_wt = prior_wt_nonicu,
                                    prior_means = priors_mean_nonicu,
                                    observations = observed_nonicu)


# create 4-dimensional arrays to store output
sim_ids <- sort(unique(as.numeric(discharge_data$sim_num)))
time_ids <- sort(unique(discharge_data$time))
county_ids <- unique(discharge_data$geoid)

simArr_icu <- array(
  data = rep(0,length(county_ids)*length(sim_ids)*length(length(time_ids))*length(priors_mean_icu)),
  dim = c(length(county_ids),length(sim_ids),length(time_ids),length(priors_mean_icu)),
  dimnames = list(county_ids,sim_ids,as.character(time_ids),names(priors_mean_icu))
)
simArr_nonicu <- array(
  data = rep(0,length(county_ids)*length(sim_ids)*length(length(time_ids))*length(priors_mean_nonicu)),
  dim = c(length(county_ids),length(sim_ids),length(time_ids),length(priors_mean_nonicu)),
  dimnames = list(county_ids,sim_ids,as.character(time_ids),names(priors_mean_nonicu))
)
simArr_icu_inflow <- simArr_icu
simArr_nonicu_inflow <- simArr_nonicu

#sort discharge data (required)
discharge_data <- discharge_data %>% arrange(time,sim_num,geoid)

dischargeArr_icu <-  array(
  data = discharge_data$icu_discharge,
  dim = c(length(county_ids),length(sim_ids),length(time_ids)),
  dimnames = list(county_ids,sim_ids,as.character(time_ids))
)

dischargeArr_nonicu <-  array(
  data = discharge_data$non_icu_discharge,
  dim = c(length(county_ids),length(sim_ids),length(time_ids)),
  dimnames = list(county_ids,sim_ids,as.character(time_ids))
)

# run simulations for icu discharges
counter <- 0
for(s in sim_ids){
  for(cntyId in county_ids){
    counter <- counter + 1
    if (counter %% 1000 == 0){
      print(paste0("Icu discharges ", 
                   round(counter / (length(sim_ids) * length(county_ids)), 4) * 100,
                   "% complete"))
    }
    sim <- simulate_post_acute(dischargeArr_icu[cntyId,s,],
                               alphas = alphas_icu,
                               losAssumps = los_icu,
                               stochastic = TRUE)
    simArr_icu[cntyId,s,,] <- sim[['census']]
    simArr_icu_inflow[cntyId,s,,] <- sim[['inflow']]
  }
}

# run simulations for non-icu discharges
counter <- 0
for(s in sim_ids){
  for(cntyId in county_ids){
    counter <- counter + 1
    if (counter %% 1000 == 0){
      print(paste0("Non-icu discharges ",
                   round(counter / (length(sim_ids) * length(county_ids)), 4) * 100,
                   "% complete"))
    }
    sim <- simulate_post_acute(dischargeArr_nonicu[cntyId,s,],
                               alphas = alphas_nonicu,
                               losAssumps = los_nonicu,
                               stochastic = TRUE)
    simArr_nonicu[cntyId,s,,] <- sim[['census']]
    simArr_nonicu_inflow[cntyId,s,,] <- sim[['inflow']]
  }
}
rm(s,cntyId)

# save raw pac ouput data
saveRDS(
  simArr_icu,
  paste(results_folder,paste0(scen_name,'_','pac_results_icu.rds'),sep ='\\')
  )
saveRDS(
  simArr_nonicu,
  paste(results_folder,paste0(scen_name,'_','pac_results_nonicu.rds'),sep ='\\')
  )
saveRDS(
  simArr_icu_inflow,
  paste(results_folder,paste0(scen_name,'_','pac_results_icu_inflow.rds'),sep ='\\')
  )
saveRDS(
  simArr_nonicu_inflow,
  paste(results_folder,paste0(scen_name,'_','pac_results_nonicu_inflow.rds'),sep ='\\')
  )

