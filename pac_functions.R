#Authors: Robert Checketts and Matt Maloney

#general information
#- this script contains custom functions for post-acute care modeling
#- these functions do not have error handling


get_discharges <- function(inputfileloc) {
  # input
  # inputfileloc: string, file location of parquet file
  
  # ouput
  # tibble
  
  raw_file <- read_parquet(inputfileloc)
  raw_file <- as.data.table(raw_file)
  
  setorder(raw_file, geoid, time)
  raw_file[, c('tot_hosp_discharge','icu_discharge') := .((shift(hosp_curr, type='lag') + incidH) - hosp_curr, (shift(icu_curr, type='lag') + incidICU) - icu_curr), by = .(uid, geoid, sim_num)]
  raw_file[is.na(tot_hosp_discharge), tot_hosp_discharge := 0]
  raw_file[is.na(icu_discharge), icu_discharge := 0]
  raw_file[, non_icu_discharge := tot_hosp_discharge - icu_discharge]
  raw_file[, .(time,geoid,sim_num,icu_discharge,non_icu_discharge,hosp_curr)]
  
  return(raw_file)
  #return(x)
}

get_updated_alphas <- function(prior_wt,prior_means,observations){
  #  description: funtion to update the generate/update alpha parameters of dirichlet distribution
  # by using information from our priors and new discharge observations
  # arguments
  # prior_wt: the 'weight' to put on our priors about allocation probabilities (integer or numeric)
  # prior_means: our priors for the allocation probability means (named numeric vector)
  # observations: observed post acute outcomes (names integer vector)
  
  #output:
  #mean 
  if(all(names(prior_means)==names(observations))){
    return(prior_wt*prior_means + observations)
  } else{
    warning('Probability list and observation names do not match; non-updated alpha values returned')
    return(prior_wt*prior_means)
  }
}

simulate_post_acute <- function(discharges,alphas,losAssumps, stochastic = TRUE){
  # arguments:
  # discharges: time series of discharge counts (integer vector)
  # alphas: alphas to parameterize dirichlet dist from which allocation probabilities are
  #   drawn (named numeric or integer vector)
  # losAssumps: length-of-stay assumptions (named numeric vector)
  # stochastic: if TRUE, take random draw from Dirichlet to get multinomial params. If FALSE,
  #   use means from Dirichlet distribution
  
  # output: list that includes PAC inflow, PAC outflow, and PAC census at each point in time
  # each list item is a  numeric matrix
  if(stochastic == TRUE){
    probs <- rdirichlet(n = 1, alpha = alphas)
  } else{
    probs <- alphas/sum(alphas)
  }
  #probs <- rdirichlet(n = 1, alpha = alphas)
  care_types <- names(alphas)
  inflowMat <- matrix(rep(0,length(alphas)*length(discharges)),
                      nrow = length(discharges),
                      ncol = length(alphas),
                      dimnames = list(1:length(discharges),care_types))
  outflowMat <- inflowMat
  discharges <- pmax(discharges,0)
  for(t in 1:length(discharges)){
    inflowMat[t,] <- rmultinom(n = 1,size = discharges[t], prob = probs)
  }
  for(ct in care_types){
    outflowMat[,ct] <- data.table::shift(inflowMat[,ct],n = losAssumps[ct],fill = 0)
  }
  list(
    'inflow' = inflowMat,
    'outflow' = outflowMat,
    'census' = apply(inflowMat, MARGIN = 2,cumsum) - apply(outflowMat, MARGIN = 2, cumsum)
  )
}

summarize_pac_sims <- function(sim_results, geoids = 'all', multiplier = 1, 
                               emp_confidence_low = .025, emp_confidence_high = .975){
  # descriptions: function that summarizes results over all simulation runs
  
  # arguments:
  # sim_results: an array produced by simulate_post_acute (4-dimensinal numeric array)
  # geoids 'all' or a character vector of one or more county geoids (character vector)
  # multiplier: multiply geoid-level discharges by this vector
  #   Should be of the same length and order as 'geoids'
  #   Can be used to calculate discharges for a specific hopital system 
  #   by multiplying geoid discharges by that sytem's market share (e.g., 0.6)
  # emp_confidence_low: percentage between 0 and 1, only used from conf_type == 'empirical'
  # emp_confidence_high: percentage between 0 and 1, only used from conf_type == 'empirical'
  
  # output:
  # data frame with mean, upper, and lower estimates summarizing all simulation runs
  
  # get care types and time ids
  care_types <- dimnames(sim_results)[[4]]
  time_ids <-  dimnames(sim_results)[[3]]
  sim_geoids <- dimnames(sim_results)[[1]]
  
  # collapse first dimension of array by summing results for all included geoids and apply
  # multipliers
  if(geoids[1] == 'all'){
    if(length(multiplier)==1){
      resultsArr <- colSums(sim_results, dim = 1)*multiplier
    } else{
      for(gId in seq_along(sim_geoids)){
        sim_results[sim_geoids[gId],,,] <- sim_results[sim_geoids[gId],,,]*multiplier[gId]
      }
      resultsArr <- colSums(sim_results, dim = 1)
    }
    resultsArr <- colSums(sim_results, dim = 1)
  } else if(length(geoids)>1) {
    for(gId in seq_along(geoids)){
      sim_results[geoids[gId],,,] <- sim_results[geoids[gId],,,]*multiplier[gId]
    }
    resultsArr <- colSums(sim_results[geoids,,,],dim = 1)
  } else{
    resultsArr <- sim_results[geoids,,,]*multiplier
  }
  
  #calculate summary stats at teach point in time
  simsSummary <- list()
  statMat <- matrix(rep(0,length(time_ids)*3),
                    nrow = length(time_ids),
                    ncol = 4,
                    dimnames = list(time_ids,c('lower','expected','upper','median')))
  for(ct in care_types){
    for(t in time_ids){
      sigma_hat <- sd(resultsArr[,t,ct])
      mean_hat <- mean(resultsArr[,t,ct])
      statMat[t,'lower'] <- max(quantile(resultsArr[,t,ct], emp_confidence_low), 0)
      statMat[t,'expected'] <- mean_hat
      statMat[t,'upper'] <- max(quantile(resultsArr[,t,ct], emp_confidence_high), 0)
      statMat[t,'median'] <- max(quantile(resultsArr[,t,ct], .5), 0)
    }
    simsSummary[[ct]] <- statMat
  }
  
  for(ct in care_types){
    simsSummary[[ct]] <- data.frame(simsSummary[[ct]])
    simsSummary[[ct]][['care_type']] <- ct
    simsSummary[[ct]][['timeid']] <- time_ids
  }
  data.frame(do.call(rbind,simsSummary)) %>%
    mutate(timeid = as.Date(timeid))
}

pac_plot_fcn <- function(simSummary,
                         titleText = 'Post-acute care outcomes',
                         subtitleText = '',
                         excluded_care_types = 'none',
                         full_names = NULL,
                         emp_confidence_low = .025,
                         emp_confidence_high = .975){
  
  # description: ggplot wrapper to streamline post-acute care plot creation
  
  ggplot(simSummary %>%
           filter(!(care_type %in% excluded_care_types)) %>%
           mutate(care_type = {
             if(is.null(full_names)){care_type}
             else {unname(full_names[care_type])}
           }),
         mapping = aes(x = timeid, color = care_type)) +
    geom_line(mapping = aes(y = expected, linetype = 'Mean'), size = 1.2) +
    geom_line(mapping = aes(y = lower, linetype = '95% Pred. Interval')) +
    geom_line(mapping = aes(y = upper, linetype = '95% Pred. Interval')) +
    scale_color_brewer(palette = 'Set1') +
    scale_linetype_manual(breaks=c("Mean",'95% Pred. Interval'), values=c(1,2)) +
    scale_y_continuous(label = scales::comma_format()) +
    labs(y = 'Patient count',
         x = 'Date',
         color = 'Care type',
         title = titleText,
         subtitle = subtitleText) + 
    theme_minimal() +
    theme(axis.text = element_text(size = 12),
          axis.title = element_text(size = 12),
          plot.subtitle = element_text(size = 12),
          plot.title = element_text(size = 14),
          legend.title = element_text(size = 11),
          legend.text = element_text(size = 11),
          plot.caption = element_text(size = 11)) +
    guides(linetype =guide_legend("Stat",override.aes = list(size = 1)),
           col=guide_legend("Care type"))
}

plot_save_function <- function(plot_object, fig_folder,fileStr, height = 4, width = 7){
  # description: function to streamline saving plots. Saves plots as .rds objects and .svg
  saveRDS(p, file = file.path(figures_folder, paste0(scen_name,'_',fileStr,'.rds')))
  svg(file = file.path(figures_folder, paste0(scen_name,'_',fileStr,'.svg')), height = height, width = width)
  print(p)
  dev.off()
}

pac_plot_fcn2 <- function(simSummary,
                          titleText = 'Post-acute care outcomes',
                          subtitleText = '',
                          y_axis_title = '',
                          excluded_care_types = 'none',
                          full_names = NULL){
  ggplot(simSummary %>%
           filter(!(care_type %in% excluded_care_types)) %>%
           mutate(care_type = {
             if(is.null(full_names)){care_type}
             else {unname(full_names[care_type])}
           }),
         mapping = aes(x = timeid, fill = care_type)) +
    geom_ribbon(
      mapping = aes(
        ymin = lower
        , ymax = upper
      )
      , alpha = .5
    ) +
    geom_line(mapping = aes(y = expected, color = care_type), alpha = 1, size = 1.2) +
    scale_color_brewer(palette = 'Set1') +
    scale_fill_brewer(palette = 'Set1') +
    scale_y_continuous(label = scales::comma_format()) +
    labs(y = y_axis_title,
         x = 'Date',
         color = 'Care type',
         title = titleText,
         subtitle = subtitleText) + 
      facet_wrap(~care_type) +
    theme_minimal() +
    theme(axis.text.y = element_text(size = 11),
          axis.title = element_text(size = 11),
          axis.text.x = element_text(angle = 45, size = 10.5, hjust = 1),
          plot.subtitle = element_text(size = 11),
          plot.title = element_text(size = 14),
          legend.title = element_text(size = 11),
          legend.text = element_text(size = 11),
          legend.position = 'none',
          plot.caption = element_text(size = 11),
          strip.text = element_text(size = 11) )
  
}
