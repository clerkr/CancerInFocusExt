library(tidyverse)

files <- list(
  "simple_ID_CT_toFacilities_v2.csv" = "ID",
  "simple_MT_CT_toFacilities_v2.csv" = "MT",
  "simple_NV_CT_toFacilities_v2.csv" = "NV",
  "simple_UT_CT_toFacilities_v3.csv" = "UT",
  "simple_WY_CT_toFacilities_v2.csv" = "WY"
)

merged_data <- bind_rows(
  lapply(names(files), function(file) {
    read_csv(file.path(getwd(), file)) %>% mutate(State = files[[file]])
  })
)


write_csv(merged_data, "facility_load_comprehensive.csv")

