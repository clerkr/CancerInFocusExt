#!/bin/bash

#### Prod Env ####

cd /srv/external/

rm -rf old
mv huntsman_catchment_data old
mkdir huntsman_catchment_data

Rscript setup/download.R

docker build -t setup-ext -f setup/Dockerfile .

docker run \
    -v /srv/external/ShinyCIF:/srv/external/ShinyCIF \
    -v /srv/external/ShinyCIFProfiles:/srv/external/ShinyCIFProfiles \
    -v /srv/external/ShinyCIFBivar:/srv/external/ShinyCIFBivar \
    -v /srv/external/huntsman_catchment_data:/srv/external/huntsman_catchment_data \
    -v /srv/external/setup:/srv/external/setup \
    setup-ext


sh setup/SHAPE/rebuild_shape.sh
sh setup/SHAPE/shape.sh

echo "Setup complete"

#### Dev Env ####

# docker build --platform linux/x86_64 -t setup -f setup/Dockerfile .

# docker run \
#     -v /Users/davidstone/Projects/SHAPE/external/ShinyCIF:/srv/external/ShinyCIF \
#     -v /Users/davidstone/Projects/SHAPE/external/ShinyCIFProfiles:/srv/external/ShinyCIFProfiles \
#     -v /Users/davidstone/Projects/SHAPE/external/ShinyCIFBivar:/srv/external/ShinyCIFBivar \
#     -v /Users/davidstone/Projects/SHAPE/external/huntsman_catchment_data:/srv/external/huntsman_catchment_data \
#     -v /Users/davidstone/Projects/SHAPE/external/setup:/srv/external/setup \
#     setup