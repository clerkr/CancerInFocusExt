## app.R ##
library(shiny)    # for shiny apps

### ITEMS TO ADJUST (marked with #!)----
recent = 'October 29, 2024'

ca = 'huntsman' #! catchment area name from CIFTools

# #!#!#! WHEN SAVING THIS FILE AS app.R, remove or comment out the following two lines of code
# path = 'C:/Users/jtburu2/ShinyCIFBivar/CIFwake2/' #! location of Shiny app
# setwd(path)

#encode image for display
b64 <- base64enc::dataURI(file = "www/cif_huntsman_bivar_big_logo_light.png", #! file name for logo
                          mime = "image/png")

#application colors
prim_bg = '#364a6c' #! primary background color
prim_acc = '#8f292d' #! primary accent color

### BEGINNING OF APPLICATION ----
#locate data files
filenames = list.files(path = "./www/locations",pattern="[0-9]{2}\\-[0-9]{2}\\-[0-9]{4}\\.(csv)")

filenames2 = mdy(str_extract(filenames, pattern = "[0-9]{2}\\-[0-9]{2}\\-[0-9]{4}"))

curr = format(max(filenames2), "%m-%d-%Y")

### load geometries----
#load shapefiles
roads_sf = st_read('www/shapefiles/roads_sf.shp')

fd = st_read("www/shapefiles/fd.shp")

state_sf = st_read("www/shapefiles/state_border_sf.shp")

county_sf = st_read("www/shapefiles/county_sf.shp") 

county_df = read.csv('www/data/all_county.csv', header = T) %>% 
    mutate(
        GEOID = str_pad(GEOID, side = 'left', width = 5, pad = '0')
        ) %>% 
    filter(is.na(Sex) | Sex == 'All',
           is.na(RE) | RE == 'All')

tract_sf = st_read("www/shapefiles/tract_sf.shp") %>% 
    select(GEOID)

tract_df = read.csv('www/data/all_tract.csv', header=T) %>% 
    mutate(
        GEOID = str_pad(GEOID, side = 'left', width = 11, pad = '0'),
    ) 

