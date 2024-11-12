# Use the official R Shiny image as the base
FROM rocker/shiny

# Install system dependencies
RUN apt-get update && apt-get install -y \
    libudunits2-dev \
    libgdal-dev \
    libgeos-dev \
    libproj-dev \
    default-jdk \
    texlive-latex-recommended \
    && R CMD javareconf

# Install packages
RUN R -e "install.packages(c('shiny', 'bslib', 'leaflet', 'dplyr', 'DT', 'forcats', 'rmarkdown', 'leaflegend', 'plotly', 'esquisse', 'scales', 'shinydashboard', 'stringr', 'htmltools', 'shinyWidgets', 'sf', 'lubridate', 'biscale', 'ggplot2', 'shinydlplot', 'pryr', 'remotes', 'shinyalert', 'shinyjs', 'classInt', 'shinybusy', 'pander', 'kableExtra', 'tinytex'))"
RUN R -e "remotes::install_github('dreamRs/capture')"

RUN Rscript -e "tinytex::install_tinytex(force = TRUE)" 

RUN Rscript -e "tinytex::tlmgr_install(c('graphicx', 'booktabs', 'longtable', 'array', 'multirow', 'float', 'colortbl', 'tabu', 'ulem', 'makecell', 'xcolor'))"

RUN echo "local(options(shiny.port = 3838, shiny.host = '0.0.0.0'))" > /usr/local/lib/R/etc/Rprofile.site

# Expose the port the app runs on
EXPOSE 3838

COPY ShinyCIFProfiles/app.R /srv/external/ShinyCIFProfiles/app.R

WORKDIR /srv/external/ShinyCIFProfiles/

CMD ["/usr/bin/shiny-server"]