library(dplyr)
library(readr)

broadband_data <- read_csv(file.path(getwd(), "shape_broadband_tract.csv"))

new_data <- broadband_data %>%
  filter(!str_detect(def, regex("Business", ignore_case = TRUE))) %>%
  filter(!str_detect(def, regex("3G", ignore_case = TRUE))) %>%
  filter(!str_detect(def, regex("Satellite", ignore_case = TRUE))) %>%
  rename(speed = value) %>%
  mutate(value = NA) %>%
  mutate(cat = "Sufficient Broadband")

# Define thresholds
terrestrial_thresholds <- c(download = 100, upload = 20)
mobile_thresholds <- c(download = 35, upload = 3)

# Revised Step 1: Evaluate individual upload/download thresholds
my_data <- new_data %>%
  mutate(
    broadband_type = gsub(" Download Speed for Residential| Upload Speed for Residential| 
                          Minimum Download Speed| Minimum Upload Speed", "", def),
    technology = case_when(
      grepl("4G|5G", def) ~ "mobile",
      TRUE ~ "terrestrial"
    ),
    type = tolower(case_when(
      grepl("download", def, ignore.case = TRUE) ~ "download",
      grepl("upload", def, ignore.case = TRUE) ~ "upload",
      TRUE ~ NA_character_
    )),
    # Individual threshold checks
    passes_download = case_when(
      technology == "terrestrial" & type == "download" ~ speed >= terrestrial_thresholds["download"],
      technology == "mobile" & type == "download" ~ speed >= mobile_thresholds["download"],
      TRUE ~ NA
    ),
    passes_upload = case_when(
      technology == "terrestrial" & type == "upload" ~ speed >= terrestrial_thresholds["upload"],
      technology == "mobile" & type == "upload" ~ speed >= mobile_thresholds["upload"],
      TRUE ~ NA
    )
  )

# Revised Step 2: Keep all original rows, add the evaluation, and modify def
combined_data <- my_data %>%
  group_by(GEOID, broadband_type) %>%
  mutate(
    combined_value = all(passes_download, na.rm = TRUE) & all(passes_upload, na.rm = TRUE),
    def = case_when(
      !grepl("4G|5G", def) ~ paste0(broadband_type, " Speed for Residential"),
      grepl("4G", def) ~ "4G Speed",
      grepl("5G", def) ~ "5G Speed",
      TRUE ~ paste0(broadband_type, " Speed")
    )
  ) %>%
  ungroup() %>%
  select(-passes_download, -passes_upload) %>%  # Remove temporary columns
  rename(original_value = value, value = combined_value) %>%  # Rename for clarity
  select(-original_value, -broadband_type, -technology, -type, -speed) %>%
  distinct(GEOID, def, .keep_all = TRUE) # Keep only one row per GEOID and new_def combination

# Step 3: To be removed when we can graph categorical data
combined_data <- combined_data %>%
  mutate(
    lbl = value,
    value = as.integer(lbl),
    lbl = case_when(
      lbl == TRUE ~ "True",
      TRUE ~ "False"
    )
  )

# Step 4: Save the final data to a CSV file
write_csv(combined_data, "broadband_sufficiency.csv")


