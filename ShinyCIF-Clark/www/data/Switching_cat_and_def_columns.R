library(dplyr)
library(readr)

# Read the data
my_data <- read_csv(file.path(getwd(), "all_tract_capstone.csv"))

broadband_data <- read_csv(file.path(getwd(), "shape_broadband_tract.csv"))

sufficiency_data <- read_csv(file.path(getwd(), "broadband_sufficiency.csv"))

broadband_clean <- broadband_data %>%
  mutate(cat = "Broadband Coverage") %>% #changing cat for our app
  mutate(lbl = as.character(lbl)) %>%  # Convert 'lbl' to character
  mutate(FacID = NA) #adding in NA for facility ID

sufficiency_data <- sufficiency_data %>%
  mutate(lbl = as.character(lbl))

merged_data <- bind_rows(my_data, broadband_clean, sufficiency_data)

# Save to a new CSV file
write_csv(merged_data, "all_tract_capstone_complete.csv")


