# Starting with files from SWFWMD ftp site
# using code Marcus wrote to unzip and combine them
# https://github.com/tbep-tech/tbep-os-presentations/blob/6ff9054aa0eb1f194a9a28e3dc8b1eff02b6a58f/state_of_the_bay_2023.qmd#L354

library(here)
library(sf)
library(tbeptools)
library(dplyr)


# from SWFWMD grid cells, use only if interested in areas finer than TB watershed
# this currently gets the same data as the compiled spreadsheet
grd <- st_read(here('GIS/swfwmd_pixel_2_utm_m_83.shp'), quiet = T)

tbgrdcent <- grd %>%
  st_transform(crs = st_crs(tbshed)) %>%
  st_centroid() %>%
  .[tbshed, ]    # tbshed is WGS 84, in tbeptools

# unzip folders
## monthly
loc <- here('SWFWMD-rainfall-data')
files <- list.files(loc, pattern = '.zip', full.names = T, recursive = T)
lapply(files, unzip, exdir = loc)
## daily
locd <- here('SWFWMD-rainfall-data', 'Daily_Data')
filesd <- list.files(locd, pattern = '.zip', full.names = T, recursive = T)
lapply(filesd, unzip, exdir = locd)

# read text files
## monthly
raindat <- list.files(loc, pattern = '19.*\\.txt$|20.*\\.txt$', full.names = T) %>%
  lapply(read.table, sep = ',', header = F) %>%
  do.call('rbind', .) %>%
  rename(
    'PIXEL' = V1,
    'month' = V2,
    'year' = V3,
    'inches' = V4
    ) %>%
  filter(PIXEL %in% tbgrdcent$PIXEL)

saveRDS(raindat, file = here(loc, "compiledRainfall.rds"))


## daily
raindatd <- list.files(locd, pattern = '19.*\\.txt$|20.*\\.txt$', full.names = T) %>%
    lapply(read.table, sep = ',', header = F) %>%
    do.call('rbind', .) %>%
    rename(
        'PIXEL' = V1,
        'date' = V2,
        'inches' = V3
    ) %>%
    filter(PIXEL %in% tbgrdcent$PIXEL)

raindatd <- raindatd |> 
    mutate(date = lubridate::mdy(date))

saveRDS(raindatd, file = here(locd, "compiledDailyRainfall.rds"))
