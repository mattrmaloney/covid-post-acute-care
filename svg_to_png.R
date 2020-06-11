library(dplyr)
library(rsvg)

#source folder with rds data
source_folder <- file.path('pac_figures')

#folder in which to save updated plots
output_folder <- file.path('pac_figures')

# Get filenames
full_loc <- list.files(pattern = ".*.svg", path = source_folder, full.names = T)
input_files <- list.files(pattern = ".*.svg", path = source_folder, full.names = F)
fileText <- substr(input_files,1,nchar(input_files)-4)

# convert svg to png
for(lId in seq_along(full_loc)){
  bitmap <- rsvg(full_loc[lId])
  png::writePNG(bitmap,file.path(output_folder,paste0(fileText[lId],'.png')), dpi = 300)
}