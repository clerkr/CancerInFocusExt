#load needed libraries
library(dplyr)
library(tidyr)
library(stringr)
library(tigris)
library(sf)
library(lubridate) #for mdy() function
library(rmapshaper) #for simplifying shapefiles
library(tidygeocoder) #for geocoding locations
library(lubridate) #for date data types
library(dialr) #for formatting phone numbers
library(tmap)

### set system variables for Cancer InFocus applications----
Sys.setenv(
    cif_dir = '/srv/external/', #path to catchment area data
    ca = 'huntsman', #catchment area short name
    
    #paths for CIF applications
    pathCIF = '/srv/external/ShinyCIF/',
    pathProfiles = '/srv/external/ShinyCIFProfiles/', #if not using CIF Profiles, set equal to ""
    pathBivar = '/srv/external/ShinyCIFBivar/' #if not using CIF Bivariate, set equal to ""
)

print('before shapefiles')
#run create shapefiles script
# setwd(dirname(rstudioapi::getActiveDocumentContext()$path)) #change working directory to directory of this script
setwd('/srv/external/setup/')
source('cif_create_shapefiles_v5.R')
print('after shapefiles')

print('before facilities')
#run geocode facilities script
# setwd(dirname(rstudioapi::getActiveDocumentContext()$path)) #change working directory to directory of this script
setwd('/srv/external/setup/')
source('cif_geocode_facilities_v5.R')
print('after facilities')