# library(tidygeocoder)
# library(lubridate)
# library(stringr)
# library(dplyr)
# library(dialr)
# library(sf)

#set paths
cif_dir = Sys.getenv('cif_dir') #main folder for CIFTools

ca = Sys.getenv('ca') #catchment area name from CIFTools

pathCIF = Sys.getenv('pathCIF') #! location for CIF app
pathProfiles = Sys.getenv('pathProfiles') #! location for CIF Profiles app, remove if not using
pathBivar = Sys.getenv('pathBivar') #! location for CIF^2 app, remove if not using

pathList = c()

for (p in c(pathCIF, pathProfiles, pathBivar)){
    if (p != ''){
        pathList = c(pathList, p)
    }
}

path2 = paste0(cif_dir, ca, '_catchment_data') #location of data from CIFTools

setwd(path2)

#find most recent date
filenames = list.files(path = ".",pattern="[0-9]{2}\\-[0-9]{2}\\-[0-9]{4}\\.(csv)")

filenames2 = mdy(str_extract(filenames, pattern = "[0-9]{2}\\-[0-9]{2}\\-[0-9]{4}"))

curr = format(max(filenames2), "%m-%d-%Y")

#load data
df = read.csv(paste0(ca, '_facilities_and_providers_', curr, '.csv'), header=T) %>%
    filter(Type != 'Obstetrics & Gynecology') %>% 
    mutate(Phone_number = format(phone(Phone_number, 'US'), format='NATIONAL', clean=F, strict=T))

#geocode locations (this step may take a while)
lat_longs1 = df %>% 
    filter(!is.na(latitude))

lat_longs2 = df %>%
    filter(is.na(latitude)) %>%
    dplyr::select(-c(latitude, longitude)) %>%
    geocode_combine(
        queries = list(
            list(method = "census", mode = "batch"),
            # list(method = "census", mode = "single"),
            list(method = "osm")
        ),
        global_params = list(address = 'Address'),
        lat = latitude,
        long = longitude
    ) %>%
    dplyr::select(-query)

lat_longs = rbind(lat_longs1, lat_longs2)

#write to file
setwd(pathCIF)

county_sf = st_read("www/shapefiles/county_sf.shp") %>%
    summarise()

lat_longs3 <- st_as_sf(lat_longs, crs = "EPSG:4326", 
                       coords = c("longitude", "latitude"), na.fail = F)

lat_longs3$dist = st_distance(lat_longs3, county_sf) %>%
    units::set_units(mi)

lat_longs4 = lat_longs3 %>% 
    dplyr::mutate(longitude = sf::st_coordinates(.)[,1],
                  latitude = sf::st_coordinates(.)[,2]) %>% 
    st_drop_geometry() %>% 
    filter(as.numeric(dist) <= 25 & !is.na(as.numeric(dist)))

for (p in pathList){
    if (p != pathProfiles & p != ""){
        setwd(p)
        write.csv(lat_longs4, paste0('www/locations/', ca, '_locations_', curr, '.csv'), row.names=F)
    }
}