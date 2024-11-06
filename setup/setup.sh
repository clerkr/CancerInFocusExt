#!/bin/bash

docker build -t setup -f setup/Dockerfile .

docker run \
    -v /srv/shiny-server/internal/ShinyCIF:/srv/shiny-server/internal/ShinyCIF \
    -v /srv/shiny-server/internal/ShinyCIFProfiles:/srv/shiny-server/internal/ShinyCIFProfiles \
    -v /srv/shiny-server/internal/ShinyCIFBivar:/srv/shiny-server/internal/ShinyCIFBivar \
    -v /srv/shiny-server/internal/huntsman_catchment_data:/srv/shiny-server/internal/huntsman_catchment_data \
    -v /srv/shiny-server/internal/setup:/srv/shiny-server/internal/setup \
    setup