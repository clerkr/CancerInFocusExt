# Use the official R Shiny image as the base
FROM rocker/shiny

# Install system dependencies
RUN apt-get update && apt-get install -y \
    libudunits2-dev \
    libgdal-dev \
    libgeos-dev \
    libproj-dev \
    default-jdk \
    && R CMD javareconf

# Install packages
RUN R -e "install.packages(c('shiny', 'bslib', 'leaflet', 'dplyr', 'DT', 'forcats', 'rmarkdown', 'leaflegend', 'plotly', 'esquisse', 'scales', 'shinydashboard', 'stringr', 'htmltools', 'shinyWidgets', 'sf', 'lubridate', 'biscale', 'ggplot2', 'shinydlplot', 'pryr', 'remotes', 'shinyalert', 'shinyjs', 'classInt', 'shinybusy'))"
RUN R -e "remotes::install_github('dreamRs/capture')"

RUN echo "local(options(shiny.port = 3838, shiny.host = '0.0.0.0'))" > /usr/local/lib/R/etc/Rprofile.site

# Expose the port the app runs on
EXPOSE 3838

COPY ShinyCIFProfiles/app.R /srv/shiny-server/internal/ShinyCIFProfiles/app.R

WORKDIR /srv/shiny-server/internal/ShinyCIFProfiles/

CMD ["/usr/bin/shiny-server"]