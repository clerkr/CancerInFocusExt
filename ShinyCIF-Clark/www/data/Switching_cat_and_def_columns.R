library(dplyr)
library(readr)

# Read the data
my_data <- read_csv(file.path(getwd(), "tract_min_FORAPP.csv"))
str(my_data)

# Swap values of 'cat' and 'def' columns
new_data <- my_data %>%
  mutate(temp = cat,  # Create a temporary column 'temp' with values from 'cat'
         cat = def,   # Assign values from 'def' to 'cat'
         def = temp) %>%  # Assign values from 'temp' to 'def'
  select(-temp) %>%  # Remove the temporary column 'temp'
  mutate(cat = "Travel time to Screening Facility") %>% # Replace all 'cat' values
  mutate(def = paste0("Minutes to ", def))  # Append "Minutes to " to each value in 'def'

# Save to a new CSV file
write_csv(new_data, "all_tract_capstone.csv")

# Check if file was created successfully
if (file.exists("all_tract_capstone.csv")) {
  print("File successfully written: all_tract_capstone.csv")
} else {
  print("Error: File was not created.")
}

