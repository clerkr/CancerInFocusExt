library(dplyr)
library(readr)

# Read the data
my_data <- read_csv(file.path(getwd(), "tract_min_FORAPP.csv"))

broadband_data <- read_csv(file.path(getwd(), "shape_broadband_tract.csv"))

sufficiency_data <- read_csv(file.path(getwd(), "broadband_sufficiency.csv"))

#FIX GASTROENTEROLOGY TO COLONOSCOPY
#
# Swap values of 'cat' and 'def' columns
new_data <- my_data %>%
  mutate(temp = cat,  # Create a temporary column 'temp' with values from 'cat'
         cat = def,   # Assign values from 'def' to 'cat'
         def = temp) %>%  # Assign values from 'temp' to 'def'
  select(-temp) %>%  # Remove the temporary column 'temp'
  mutate(def = if_else(def == "Gastroenterology", "Colonoscopy", def)) %>% #Gastro to Colonoscopy
  mutate(cat = "Travel time to Screening Facility") %>% # Replace all 'cat' values
  mutate(def = paste0("Minutes to ", def)) %>% # Append "Minutes to " to each value in 'def'
  mutate(fmt = "int") %>% #changing fmt to int to see if it will fix the legend
  mutate(lbl = as.character(lbl)) %>%  # Convert 'lbl' to character
  mutate(lbl = paste0(lbl, " min"))  # Append " min" to each value in 'lbl'

broadband_clean <- broadband_data %>%
  mutate(cat = "Broadband Coverage") %>% #changing cat for our app
  mutate(lbl = as.character(lbl)) %>%  # Convert 'lbl' to character
  mutate(FacID = NA) #adding in NA for facility ID

sufficiency_data <- sufficiency_data %>%
  mutate(lbl = as.character(lbl))

merged_data <- bind_rows(new_data, broadband_clean, sufficiency_data)

# Save to a new CSV file
write_csv(merged_data, "all_tract_capstone_complete.csv")


