# Use the official R Shiny image as the base
FROM rocker/shiny

# Install system dependencies
RUN apt-get update && apt-get install -y \
    libudunits2-dev \
    libgdal-dev \
    libgeos-dev \
    libproj-dev \
    default-jdk \
    systemd \
    acl \
    && R CMD javareconf

# Install packages
RUN R -e "install.packages(c('shiny', 'bslib', 'leaflet', 'dplyr', 'DT', 'forcats', 'rmarkdown', 'leaflegend', 'plotly', 'esquisse', 'scales', 'shinydashboard', 'stringr', 'htmltools', 'shinyWidgets', 'sf', 'lubridate', 'biscale', 'ggplot2', 'shinydlplot', 'pryr', 'remotes', 'shinyalert', 'shinyjs', 'classInt', 'shinybusy'))"
RUN R -e "remotes::install_github('dreamRs/capture')"

COPY shiny-server/shiny-server.conf /etc/shiny-server/shiny-server.conf

RUN systemctl enable shiny-server

# CMD ["setfacl", "-R", "-m", "u:shiny:rw", "/srv/shiny-server/internal/"]

COPY shiny-server/entrypoint.sh /srv/shiny-server/internal/shiny-server/entrypoint.sh
RUN chmod +rwx /srv/shiny-server/internal/shiny-server/entrypoint.sh
ENTRYPOINT ["/srv/shiny-server/internal/shiny-server/entrypoint.sh"]
