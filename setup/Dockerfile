# Use the official R Shiny image as the base
FROM rocker/geospatial

# Install packages needed for setup script
RUN R -e "install.packages(c('dplyr', 'tidyr', 'stringr', 'tigris', 'sf', 'lubridate', 'rmapshaper', 'tidygeocoder', 'dialr', 'tmap', 'rstudioapi'))"

# Install system dependencies
RUN apt-get update && apt-get install -y \
    default-jdk \
    && R CMD javareconf

# Run setup script
CMD ["Rscript", "/srv/external/setup/CIFvars_v5.R"]


