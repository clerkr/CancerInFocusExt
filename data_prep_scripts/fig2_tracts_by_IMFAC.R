library(tigris) # Allows users to directly download and use TIGER/Line shapefiles from the census.gov website
library(ggplot2)
library(sf)
library(dplyr)
library(svglite)

options(tigris_use_cache = TRUE)

input_file <- readline(prompt = "What is the path to your input file? ") # C:/Users/kirst/BIO465/allTracts_complete.csv
output_file <- readline(prompt = "What is the path to your output file? ") # C:/Users/kirst/BIO465/5states_borders.svg

input_path <- function() {
    return(input_file) 
}

output_path <- function() {
    return(output_file)
}

# Load census tracts for each state from tigris
utah_tracts <- tracts(state = "UT", year = 2020)
idaho_tracts <- tracts(state = "ID", year = 2020)
nevada_tracts <- tracts(state = "NV", year = 2020)
wyoming_tracts <- tracts(state = "WY", year = 2020)
montana_tracts <- tracts(state = "MT", year = 2020)

# Load CSV and keep only the first 2 columns (aka the TractID and TractLabel)
data <- read.csv(input_path(), header=TRUE)
data <- data[, 1:2]  

# Rename columns to match expected key
colnames(data) <- c("GEOID", "Label") 
data$GEOID <- as.character(data$GEOID)
data$Label[data$Label == ""] <- "No Data"


# Merge the states to our csv data
merged_utah <- inner_join(utah_tracts, data, by = "GEOID")
merged_idaho <- inner_join(idaho_tracts, data, by = "GEOID")
merged_nevada <- inner_join(nevada_tracts, data, by = "GEOID")
merged_wyoming <- inner_join(wyoming_tracts, data, by = "GEOID")
merged_montana <- inner_join(montana_tracts, data, by = "GEOID")

# Combine data for all states
merged_data <- rbind(merged_utah, merged_idaho, merged_nevada, merged_wyoming, merged_montana)

# Convert merged_data back to sf if necessary
if (!inherits(merged_data, "sf")) {
  merged_data <- st_as_sf(merged_data)  # Convert to sf object
}

# Load state boundaries for plotting
states <- states(year = 2020)  # Fetch state boundaries
states <- states[states$STUSPS %in% c("UT", "ID", "NV", "WY", "MT"), ]


ggplot(data = merged_data) +
  geom_sf(aes(fill = Label), color = NA) +  # No tract borders
  geom_sf(data = states, fill = NA, color = "white", size = 0.5) +  # State borders added
  scale_fill_manual(
    values = c(
        "Metropolitan" = "#F0CEA0", # light yellow
        "Micropolitan" = "#C0C286", #  light green
        "Frontier-Micropolitan" = "#0B8697", #dark teal
        "Frontier-Small Town/Rural" = "#1B065E", #dark blue
        "Small Town/Rural" = "#5D2675", #dark purple
        "No Data" = "#6F686D"),
        limits = c("Small Town/Rural", "Frontier-Small Town/Rural", 
           "Frontier-Micropolitan", "Micropolitan", "Metropolitan", "No Data")
        ) +  # Custom color mapping
  theme_minimal() +
  labs(title = "", # Visualized Rurality by Census Tracts in Intermountain West
       subtitle = "") + # 2020 Census Data Colored by IMFAC Label
  guides(fill = guide_legend(reverse = FALSE)) +
  theme( # Removing all the grid lines and labels
    panel.grid.major = element_blank(),  
    panel.grid.minor = element_blank(),  
    axis.text = element_blank(),        
    axis.ticks = element_blank(),       
    axis.title = element_blank()
  )

# Save the plot
ggsave(output_path(), plot = last_plot(), dpi = 300, width = 12, height = 8, device = "svg")
