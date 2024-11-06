## app.R ##
# library(dplyr)
# library(tidyr)
# library(stringr)
# library(tigris)
# library(sf)
# library(lubridate) #for mdy() function
# library(rmapshaper)

cif_dir = Sys.getenv('cif_dir') #main folder for CIFTools

ca = Sys.getenv('ca') #catchment area name from CIFTools

pathCIF = Sys.getenv('pathCIF') #location for CIF app
pathProfiles = Sys.getenv('pathProfiles') #location for CIF Profiles app
pathBivar = Sys.getenv('pathBivar') #location for CIF^2 app

pathList = c()

for (p in c(pathCIF, pathProfiles, pathBivar)){
    if (p != ''){
        pathList = c(pathList, p)
    }
}

path2 = paste0(cif_dir, ca, '_catchment_data') #location of data from CIFTools

setwd(pathCIF)

####read data files----
#load measure dictionary file
nice_names = read.csv("www/measure_dictionary_v5.csv", header=T) #cleans names and data type

####load data from CIFTools----
###load county data----

setwd(path2)

filenames = list.files(path = ".",pattern="[0-9]{2}\\-[0-9]{2}\\-[0-9]{4}\\.(csv)")

filenames2 = mdy(str_extract(filenames, pattern = "[0-9]{2}\\-[0-9]{2}\\-[0-9]{4}"))

curr = format(max(filenames2), "%m-%d-%Y")

#load sociodemographic data
sd_county <- read.csv(paste0(ca, "_sociodemographics_county_long_", curr, ".csv"),
                      colClasses = c("FIPS" = "character"),
                      header = T) %>%
    mutate(measure = str_replace_all(measure, "_", " "),
           cat = "Sociodemographics",
           RE = NA,
           Sex = NA) %>%
    left_join(nice_names, by="measure") %>%
    mutate(lbl = case_when(
        fmt == "pct" ~ paste0(round(value*100, 1), "%"),
        fmt == "int" ~ prettyNum(round(value, 2), big.mark = ",")
    )) %>%
    select(cat, everything())

#load economic data
econ_county = read.csv(paste0(ca, "_economy_county_long_", curr, ".csv"),
                       colClasses = c("FIPS" = "character"), header = T) %>%
    mutate(measure = str_replace_all(measure, "_", " "),
           cat = "Economics & Insurance",
           RE = NA,
           Sex = NA) %>%
    left_join(nice_names, by="measure") %>%
    mutate(lbl = case_when(
        fmt == "pct" ~ paste0(round(value*100, 1), "%"),
        fmt == "int" ~ prettyNum(round(value, 2), big.mark = ",")
    )) %>%
    filter(def != "NA") %>%
    select(cat, everything())

#load housing and transportation data
ht_county = read.csv(paste0(ca, "_housing_trans_county_long_", curr, ".csv"),
                       colClasses = c("FIPS" = "character"), header = T) %>%
    mutate(measure = str_replace_all(measure, "_", " "),
           cat = "Housing & Transportation",
           RE = NA,
           Sex = NA) %>%
    left_join(nice_names, by="measure") %>%
    mutate(lbl = case_when(
        fmt == "pct" ~ paste0(round(value*100, 1), "%"),
        fmt == "int" ~ prettyNum(round(value, 2), big.mark = ",")
    )) %>%
    filter(def != "NA") %>%
    select(cat, everything())

#load disparity data
disp_county = read.csv(paste0(ca, "_disparity_county_long_", curr, ".csv"),
                     colClasses = c("FIPS" = "character"), header = T) %>%
    mutate(measure = str_replace_all(measure, "_", " "),
           cat = "Disparities",
           RE = NA,
           Sex = NA) %>%
    left_join(nice_names, by="measure") %>%
    mutate(lbl = case_when(
        fmt == "pct" ~ paste0(round(value*100, 1), "%"),
        fmt == "int" ~ prettyNum(round(value, 2), big.mark = ",")
    )) %>%
    filter(def != "NA") %>%
    select(cat, everything())

#load cancer incidence
ci_county = read.csv(paste0(ca, "_cancer_incidence_county_long_", curr, ".csv"),
                         colClasses = c("FIPS" = "character"), header = T) %>%
    rename(value = AAR) %>%
    mutate(measure = paste(Type, Site, sep = " "),
           FIPS = as.character(FIPS),
           measure = str_replace_all(measure, "_", " "),
           cat = "Cancer Incidence (age-adj per 100k)") %>%
    inner_join(nice_names, by="measure") %>%
    mutate(lbl = case_when(
        fmt == "pct" ~ paste0(round(value*100, 1), "%"),
        fmt == "int" ~ prettyNum(value, big.mark=","),
        is.na(value) ~ "Rate Suppressed (Less than 16 cases)"
    )) %>%
    select(-c(Type, Site, AAC)) %>%
    select(cat, everything()) 

#load cancer mortality data
cm_county_all = read.csv(paste0(ca, "_cancer_mortality_county_long_", curr, ".csv"),
                         colClasses = c("FIPS" = "character"),
                         header=T) %>%
    rename(value = AAR) %>%
    mutate(measure = paste(Type, Site, sep = " "),
           measure = str_replace_all(measure, "_", " "),
           cat = "Cancer Mortality (age-adj per 100k)") %>%
    inner_join(nice_names, by="measure") %>%
    mutate(lbl = case_when(
        fmt == "pct" ~ paste0(round(value*100, 1), "%"),
        fmt == "int" ~ prettyNum(value, big.mark=","),
        is.na(value) ~ "Rate Suppressed (Less than 16 cases)"
    )) %>%
    select(-c(Type, Site, AAC)) %>%
    select(cat, everything()) %>%
    arrange(def)

cm_county_sex = read.csv(paste0(ca, "_cancer_mortality_county_long_", curr, ".csv"),
                         colClasses = c("FIPS" = "character"),
                         header=T) %>%
    filter((Sex == 'Female' & Site %in% c('Cervix', 'Female Breast', 'Ovary')) |
               (Sex == 'Male' & Site == 'Prostate')) %>% 
    rename(value = AAR) %>%
    mutate(measure = paste(Type, Site, sep = " "),
           measure = str_replace_all(measure, "_", " "),
           Sex = 'All',
           cat = "Cancer Mortality (age-adj per 100k)") %>%
    inner_join(nice_names, by="measure") %>%
    mutate(lbl = case_when(
        fmt == "pct" ~ paste0(round(value*100, 1), "%"),
        fmt == "int" ~ prettyNum(value, big.mark=","),
        is.na(value) ~ "Rate Suppressed (Less than 16 cases)"
    )) %>%
    select(-c(Type, Site, AAC)) %>%
    select(cat, everything()) %>%
    arrange(def)

cm_county = rbind(cm_county_all, cm_county_sex) %>% 
    arrange(def)

#load environmental data
env_county = read.csv(paste0(ca, "_environment_county_long_", curr, ".csv"),
                      colClasses = c("FIPS" = "character"), header = T) %>%
    mutate(measure = str_replace_all(measure, "_", " "),
           cat = "Environment",
           RE = NA,
           Sex = NA) %>%
    left_join(nice_names, by="measure") %>%
    mutate(lbl = case_when(
        fmt == "pct" ~ paste0(round(value*100, 1), "%"),
        fmt == "int" ~ prettyNum(round(value, 2), big.mark = ",")
    )) %>%
    filter(def != "NA") %>%
    select(cat, everything())

#load risk factor & screening data
rf_county = read.csv(paste0(ca, "_rf_and_screening_county_long_", curr, ".csv"),
                     colClasses = c("FIPS" = "character"),
                     header=T) %>%
    filter(measure %in% c('Met_Breast_Screen', 'Met_Colon_Screen', 
                          'Currently_Smoke', 'BMI_Obese', 'Physically_Inactive', 
                          'Binge_Drinking', 'Sleep_Debt', 'Cancer_Prevalence')) %>% 
    mutate(measure = str_replace_all(measure, "_", " "),
           cat = "Screening & Risk Factors",
           RE = NA,
           Sex = NA) %>%
    left_join(nice_names, by="measure") %>%
    mutate(lbl = case_when(
        fmt == "pct" ~ paste0(round(value*100, 1), "%"),
        fmt == "int" ~ prettyNum(round(value, 2), big.mark = ",")
    )) %>%
    select(cat, everything()) 

hf_county = read.csv(paste0(ca, "_rf_and_screening_county_long_", curr, ".csv"),
                     colClasses = c("FIPS" = "character"),
                     header=T) %>%
    filter(!(measure %in% c('Met_Breast_Screen', 'Met_Colon_Screen', 
                            'Currently_Smoke', 'BMI_Obese', 'Physically_Inactive', 
                            'Binge_Drinking', 'Sleep_Debt', 'Cancer_Prevalence'))) %>% 
    mutate(
        measure = case_when(
            measure == 'Self-care_Disability' ~ 'Selfcare_Disability',
            .default = measure
        ),
        measure = str_replace_all(measure, "_", " "),
        cat = "Other Health Factors",
        RE = NA,
        Sex = NA
    ) %>%
    left_join(nice_names, by="measure") %>%
    mutate(lbl = case_when(
        fmt == "pct" ~ paste0(round(value*100, 1), "%"),
        fmt == "int" ~ prettyNum(round(value, 2), big.mark = ",")
    )) %>%
    select(cat, everything()) 

#bind all county data
all_county = rbind(sd_county, econ_county, env_county, ht_county, disp_county,
                   rf_county, hf_county, ci_county, cm_county) %>% 
    rename(GEOID = FIPS)

all_county2 = all_county %>% 
    rename(area = County) %>% 
    mutate(value = ifelse(is.na(value), 0, value)) %>% 
    filter(Sex  == 'All' | is.na(Sex), 
           RE  == 'All' | is.na(RE))

countyMedian = all_county2 %>% 
    group_by(cat, measure, def, fmt) %>% 
    summarise(value = median(value, na.rm=T)) %>% 
    ungroup() %>% 
    mutate(med_lbl = case_when(
        fmt == "pct" ~ paste0(round(value*100, 1), "%"),
        fmt == "int" ~ prettyNum(round(value, 2), big.mark = ",")
    )) %>% 
    select(-c(fmt, value))

countyMedian2 = all_county2 %>% 
    left_join(countyMedian, by = c('cat', 'measure', 'def'))

###bring in shapefiles----
states = unique(rf_county$State)

options(tigris_use_cache = T)

#get 2020 tracts
tr20 = c()

for (s in states){
    tr20.st = tracts(
        state = s,
        cb = T,
        keep_zipped_shapefile = T,
        refresh = F
    ) %>%
        select(-c(NAMELSAD, STUSPS, NAMELSADCO, STATE_NAME, ALAND, AWATER)) 
    
    tr20 = rbind(tr20, tr20.st)
}

tr20 = tr20 %>% 
    sf::st_transform(4326) %>%
    ms_simplify(keep = 0.2, keep_shapes = T)

#get 2010 tracts
tr10 = c()

for (s in states){
    tr10.st = tracts(
        state = s,
        cb = T,
        year = 2019,
        keep_zipped_shapefile = T,
        refresh = F
    ) %>%
        select(-c(ALAND, AWATER)) 
    
    tr10 = rbind(tr10, tr10.st)
}

tr10 = tr10 %>% 
    sf::st_transform(4326) %>%
    ms_simplify(keep = 0.2, keep_shapes = T)

#get counties
co = tr20 %>%
    mutate(GEOID = paste0(STATEFP, COUNTYFP)) %>%
    group_by(GEOID) %>%
    summarise()

#get states
st = tr20 %>%
    group_by(STATEFP) %>%
    summarise()

###load tract data using 2020 tracts----
#load sociodemographic data
sd_tract = read.csv(paste0(ca, "_sociodemographics_tract_long_", curr, ".csv"),
                    colClasses = c("FIPS" = "character"),
                    header = T) %>%
    mutate(measure = str_replace_all(measure, "_", " "),
           cat = "Sociodemographics",
           RE = NA,
           Sex = NA) %>%
    left_join(nice_names, by="measure") %>%
    mutate(lbl = case_when(
        fmt == "pct" ~ paste0(round(value*100, 1), "%"),
        fmt == "int" ~ prettyNum(round(value, 2), big.mark = ",")
    )) %>%
    select(cat, everything())

#load economic data
econ_tract = read.csv(paste0(ca, '_economy_tract_long_', curr, '.csv'),
                      colClasses = c("FIPS" = "character"),
                      header=T) %>%
    mutate(measure = str_replace_all(measure, "_", " "),
           cat = "Economics & Insurance",
           RE = NA,
           Sex = NA) %>%
    left_join(nice_names, by="measure") %>%
    mutate(lbl = case_when(
        fmt == "pct" ~ paste0(round(value*100, 1), "%"),
        fmt == "int" ~ prettyNum(round(value, 2), big.mark = ",")
    )) %>%
    select(cat, everything()) %>%
    arrange(def)

#load housing and transportation data
ht_tract = read.csv(paste0(ca, '_housing_trans_tract_long_', curr, '.csv'),
                    colClasses = c("FIPS" = "character"),
                    header=T) %>%
    mutate(measure = str_replace_all(measure, "_", " "),
           cat = "Housing & Transportation",
           RE = NA,
           Sex = NA) %>%
    left_join(nice_names, by="measure") %>%
    mutate(lbl = case_when(
        fmt == "pct" ~ paste0(round(value*100, 1), "%"),
        fmt == "int" ~ prettyNum(round(value, 2), big.mark = ",")
    )) %>%
    select(cat, everything()) %>%
    arrange(def)

#load disparity data
disp_tract = read.csv(paste0(ca, '_disparity_tract_long_', curr, '.csv'),
                      colClasses = c("FIPS" = "character"),
                      header=T) %>%
    mutate(measure = str_replace_all(measure, "_", " "),
           cat = "Disparities",
           RE = NA,
           Sex = NA) %>%
    left_join(nice_names, by="measure") %>%
    mutate(lbl = case_when(
        fmt == "pct" ~ paste0(round(value*100, 1), "%"),
        fmt == "int" ~ prettyNum(round(value, 2), big.mark = ",")
    )) %>%
    select(cat, everything()) %>%
    arrange(def)

env_tract = read.csv(paste0(ca, '_environment_tract_long_', curr, '.csv'),
                     colClasses = c('FIPS' = 'character'),
                     header=T) %>%
    mutate(cat = "Environment",
           RE = NA,
           Sex = NA) %>%
    left_join(nice_names, by="measure") %>%
    mutate(lbl = case_when(
        fmt == "pct" ~ paste0(round(value*100, 1), "%"),
        fmt == "int" ~ prettyNum(round(value, 2), big.mark = ",")
    )) %>%
    select(cat, everything()) %>%
    arrange(def)

county20 = sd_county[,'FIPS'] #use to fill in blank tracts
tracts20 = tr20[,'GEOID'] %>% st_drop_geometry()

rf_tract = read.csv(paste0(ca, "_rf_and_screening_tract_", curr, ".csv"),
                    colClasses = c("FIPS" = "character"),
                    header=T)  %>%
    select(FIPS, County, State, 'Met_Breast_Screen', 'Met_Colon_Screen', 
           'Currently_Smoke', 'BMI_Obese', 'Physically_Inactive', 
           'Binge_Drinking', 'Sleep_Debt', 'Cancer_Prevalence') %>% 
    left_join(tracts20, ., by = c("GEOID" = "FIPS")) %>%
    rename(FIPS = GEOID) %>%
    filter(substr(FIPS,1,5) %in% county20) %>%
    mutate(Tract = paste0("Census Tract ", substr(FIPS, 6, 9), ".", substr(FIPS, 10, 11)),
           cat = "Screening & Risk Factors",
           RE = NA,
           Sex = NA) %>%
    pivot_longer(cols = c('Met_Breast_Screen', 'Met_Colon_Screen', 
                          'Currently_Smoke', 'BMI_Obese', 'Physically_Inactive', 
                          'Binge_Drinking', 'Sleep_Debt', 'Cancer_Prevalence'), 
                 names_to = 'measure', values_to = 'value') %>%
    mutate(measure = str_replace_all(measure, "_", " ")) %>%
    left_join(nice_names, by="measure") %>%
    mutate(value = value / 100,
           lbl = case_when(
               fmt == "pct" ~ paste0(round(value * 100, 1), "%"),
               fmt == "int" ~ prettyNum(round(value, 2), big.mark = ",")
           )) %>%
    select(cat, everything())

hf_tract = read.csv(paste0(ca, "_rf_and_screening_tract_", curr, ".csv"),
                    colClasses = c("FIPS" = "character"),
                    header=T)  %>%
    select(FIPS, County, State, 'Bad_Health', 'Poor_Physical', 'Poor_Mental', 
           'Depression', 'Diabetes_DX', 'High_BP', 'High_Cholesterol', 'BP_Medicine', 'CHD', 'Had_Stroke', 
           'Asthma', 'COPD', 'No_Teeth', 'Recent_Checkup', 'Recent_Dentist',
           'Hearing_Disability', 'Vision_Disability', 'Cognitive_Disability',
           'Mobility_Disability', 'Selfcare_Disability', 'Independent_Living_Disability',
           'Socially_Isolated', 'Food_Insecure', 'Housing_Insecure',
           'Lacked_Reliable_Transportation', 'Lacked_Social_Emotional_Support') %>% 
    left_join(tracts20, ., by = c("GEOID" = "FIPS")) %>%
    rename(FIPS = GEOID) %>%
    filter(substr(FIPS,1,5) %in% county20) %>%
    mutate(Tract = paste0("Census Tract ", substr(FIPS, 6, 9), ".", substr(FIPS, 10, 11)),
           cat = "Other Health Factors",
           RE = NA,
           Sex = NA) %>%
    pivot_longer(cols = c('Bad_Health', 'Poor_Physical', 'Poor_Mental', 
                          'Depression', 'Diabetes_DX', 'High_BP', 'High_Cholesterol', 'BP_Medicine', 'CHD', 'Had_Stroke', 
                          'Asthma', 'COPD', 'No_Teeth', 'Recent_Checkup', 'Recent_Dentist',
                          'Hearing_Disability', 'Vision_Disability', 'Cognitive_Disability',
                          'Mobility_Disability', 'Selfcare_Disability', 'Independent_Living_Disability',
                          'Socially_Isolated', 'Food_Insecure', 'Housing_Insecure',
                          'Lacked_Reliable_Transportation', 'Lacked_Social_Emotional_Support'), 
                 names_to = 'measure', values_to = 'value') %>%
    mutate(measure = str_replace_all(measure, "_", " ")) %>%
    left_join(nice_names, by="measure") %>%
    mutate(value = value / 100,
           lbl = case_when(
               fmt == "pct" ~ paste0(round(value * 100, 1), "%"),
               fmt == "int" ~ prettyNum(round(value, 2), big.mark = ",")
           )) %>%
    select(cat, everything())

#bind all tract data using 2020 tracts
all_tract = rbind(sd_tract, econ_tract, ht_tract, disp_tract, env_tract, rf_tract, hf_tract) %>% 
    rename(GEOID = FIPS)

###load tract data using 2010 tracts----
#load environmental data
fd_tract = read.csv(paste0(ca, '_food_desert_tract_long_', curr, '.csv'),
                    colClasses = c('FIPS' = 'character'),
                    header=T) %>%
    mutate(cat = "Environment") %>%
    select(cat, everything()) 

####prepare data----
#join data to shapefiles
fd = right_join(tr10, fd_tract, by=c('GEOID' = 'FIPS')) %>%
    group_by(value) %>%
    filter(value == 1) %>%
    summarise() 

state_border_sf = st 

county_sf <- co %>% 
    filter(GEOID %in% unique(all_county$GEOID))

county_border_sf = county_sf %>% 
    group_by(GEOID) %>% 
    summarise()

tract_sf = tr20 %>% 
    filter(GEOID %in% unique(all_tract$GEOID))

#get roads shapefiles
temp = tempfile()
temp2 = tempfile()

#download zip file
download.file('https://www2.census.gov/geo/tiger/TIGER2023/PRIMARYROADS/tl_2023_us_primaryroads.zip', temp)
unzip(zipfile = temp, exdir = temp2)
roads = st_read(file.path(temp2, 'tl_2023_us_primaryroads.shp')) %>%
    sf::st_transform(4326)

#unlink the temp file
unlink(c(temp, temp2))

#intersect roads with catchment area
bounding_box <- county_border_sf %>% 
    summarise() %>% 
    st_as_sfc()

ca_roads = roads %>% 
    filter(RTTYP %in% c('I', 'U', 'M')) %>% 
    st_intersection(bounding_box) 

#write data to file----
for (p in pathList){
    setwd(p)
    
    if (!dir.exists(paste0(p, "/www/shapefiles"))){
        dir.create(paste0(p, "/www/shapefiles"))
    }
    
    if (!dir.exists(paste0(p, "/www/locations"))){
        dir.create(paste0(p, "/www/locations"))
    }
    
    if (!dir.exists(paste0(p, "/www/data"))){
        dir.create(paste0(p, "/www/data"))
    }
    
    st_write(fd, "www/shapefiles/fd.shp", append=F)
    st_write(ca_roads, "www/shapefiles/roads_sf.shp", append=F)
    st_write(state_border_sf, "www/shapefiles/state_border_sf.shp", append=F)
    st_write(county_border_sf, "www/shapefiles/county_border_sf.shp", append=F)
    st_write(county_sf, "www/shapefiles/county_sf.shp", append=F)
    write.csv(all_county, 'www/data/all_county.csv', row.names = F)
    
    if (p == pathProfiles & pathProfiles != ""){
        write.csv(countyMedian2, 'www/data/county_median.csv', row.names = F)
    }
    
    if (p != pathProfiles & p != ""){
        write.csv(all_tract, 'www/data/all_tract.csv', row.names = F)
        st_write(tract_sf, "www/shapefiles/tract_sf.shp", append=F)
    }
}