# Set up the workspace so it can be the same across different chapters  
library(sf)
library(tidyverse)

# Spatial ----

swfwmdpixels <- read_sf(here::here("GIS", "swfwmd_pixel_2_utm_m_83.shp"))
bay_segs <- read_sf(here::here("GIS", "TBEP-Bay_Segments.shp")) |> 
    st_transform(crs = st_crs(swfwmdpixels))


# Hydro + processing ----
hydro <- readxl::read_xlsx(here::here("hydro-load-data",
                                      "monthly-hydrology.xlsx"))

hydro <- hydro |> 
    rename(hydro_load = hy_load_106_m3_mo) |>
    group_by(bay_segment) |> 
    mutate(lag1_hydro = lag(hydro_load)) |> 
    ungroup()


# Precip subsetting ----

# Subset pixel file, merge datasets that need merging, turn into spatial objects.

precip_pixels <- st_intersection(swfwmdpixels, bay_segs)

# pixels to pull rainfall from,
# and their associated bay segments
# (for group-wise averaging)  
pixs <- precip_pixels |> 
    st_drop_geometry() |> 
    select(PIXEL, BAY_SEG)

# monthly (see R/rainfall_preprocessing.R)
prcp <- readRDS(here::here("SWFWMD-rainfall-data", "compiledRainfall.rds"))

# daily  
daily_prcp <- readRDS(here::here("SWFWMD-rainfall-data", "Daily_Data", "compiledDailyRainfall.rds"))


# Precip spatial joining ----

# pull a few months and map both by pixel, 
# and averaged up to bay segment
# make sure it works  

# there are some pixels along bay segment boundaries
# I set this to be a full join so that the precip from
# those pixels goes into each bay segment average
# that they're part of

prcp <- prcp |> 
    full_join(pixs, by = "PIXEL",
              relationship = "many-to-many") |> 
    group_by(PIXEL) |> 
    mutate(prcp_lag1 = lag(inches)) |> 
    ungroup()

daily_prcp <- daily_prcp |> 
    full_join(pixs, by = "PIXEL",
              relationship = "many-to-many") |> 
    group_by(PIXEL) |> 
    mutate(daily_lag1 = lag(inches, 1),
           daily_lag2 = lag(inches, 2),
           daily_lag3 = lag(inches, 3),
           daily_lag4 = lag(inches, 4),
           daily_lag5 = lag(inches, 5),
           daily_lag6 = lag(inches, 6),
           daily_24hrs = inches + daily_lag1,
           daily_48hrs = inches + daily_lag1 + daily_lag2,
           daily_7d = inches + daily_lag1 + daily_lag2 + daily_lag3 + daily_lag4 + daily_lag5 + daily_lag6) |> 
    ungroup() |> 
    select(PIXEL, date, inches, BAY_SEG, 
           daily_24hrs, daily_48hrs, daily_7d)


prcp_daily_bayseg <- daily_prcp |> 
    summarize(.by = c(BAY_SEG, date),
              across(c(inches, daily_24hrs, daily_48hrs, daily_7d),
                     function(x) mean(x, na.rm = TRUE)))

# Combine rain and hydro loads ----
combnd <- prcp |> 
    mutate(bay_segment = case_match(BAY_SEG,
                                    "Boca Ciega Bay" ~ "Remainder Lower Tampa Bay",
                                    "Manatee River" ~ "Remainder Lower Tampa Bay",
                                    "Terra Ceia Bay" ~ "Remainder Lower Tampa Bay",
                                    .default = BAY_SEG)) |> 
    summarize(.by = c(bay_segment, month, year),
              inches = mean(inches, na.rm = TRUE)) |> 
    group_by(bay_segment) |> 
    mutate(lag1_prcp = lag(inches)) |> 
    ungroup() |> 
    filter(year >= 2009,
           bay_segment %in% unique(hydro$bay_segment)) |>
    left_join(hydro, by = c("bay_segment", "year", "month"))


# Save relevant data frames ----

save(prcp, prcp_daily_bayseg, precip_pixels, hydro, combnd,
     file = here::here("sourced_data", "combined_precip.RData"))
save(bay_segs, swfwmdpixels,
     file = here::here("sourced_data", "combined_spatial.RData"))
