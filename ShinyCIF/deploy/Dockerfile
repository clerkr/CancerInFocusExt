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
RUN R -e "install.packages(c('shiny', 'bslib', 'leaflet', 'dplyr', 'leaflegend', 'esquisse', 'scales', 'shinydashboard', 'stringr', 'htmltools', 'shinyWidgets', 'sf', 'lubridate', 'pryr', 'remotes', 'shinyalert', 'shinyjs', 'classInt', 'shinybusy'))"
RUN R -e "remotes::install_github('dreamRs/capture')"

RUN echo "local(options(shiny.port = 3838, shiny.host = '0.0.0.0'))" > /usr/local/lib/R/etc/Rprofile.site

# Expose the port the app runs on
EXPOSE 3838

COPY ShinyCIF/app.R /srv/external/ShinyCIF/app.R

WORKDIR /srv/external/ShinyCIF/

CMD ["/usr/bin/shiny-server"]