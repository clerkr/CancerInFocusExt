#!/bin/bash

docker build -t setup -f setup/Dockerfile .

docker run \
    -v /srv/external/ShinyCIF:/srv/external/ShinyCIF \
    -v /srv/external/ShinyCIFProfiles:/srv/external/ShinyCIFProfiles \
    -v /srv/external/ShinyCIFBivar:/srv/external/ShinyCIFBivar \
    -v /srv/external/huntsman_catchment_data:/srv/external/huntsman_catchment_data \
    -v /srv/external/setup:/srv/external/setup \
    setup