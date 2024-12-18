library(tidyverse)

#set path for where to write files
path = 'huntsman_catchment_data' #! point to the folder on your machine

setwd(path)

#set catchment area short name
caZip = 'huntsman.zip' #! use the catchment area zip file name for your catchment area from catchment_area_crosswalk.csv

#define function for downloading zip file and writing CSVs to disk
download_cif_data = function(area){
    #create tempfile to store zip file in
    temp = tempfile()
    
    #download zip file
    download.file(paste0("https://cancerinfocus.org/public-data/Current/", area), temp)
    
    #read files inside zip file
    files = unzip(temp, list = TRUE)
    
    #locate CSV files inside zip file
    csvs = files$Name[str_detect(files$Name, pattern = '.csv')]
    
    #read each CSV from the zip file and write them to disk
    for (c in csvs){
        df = read.csv(unz(temp, c))
        write.csv(df, c, row.names=F)
    }
    
    #unlink the temp file
    unlink(temp)
}

#call function on your catchment area
download_cif_data(caZip)