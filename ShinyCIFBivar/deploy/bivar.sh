
#### Prod Env ####

# docker build -t bivar-ext -f ShinyCIFBivar/deploy/Dockerfile .

# docker run \
#     -v /srv/external/:/srv/external/ \
#     -v /var/log/shiny-server:/var/log/shiny-server \
#     -p 3840:3840 \
#     bivar-ext

#### Dev Env ####

docker build --platform linux/x86_64 -t bivar-ext -f ShinyCIFBivar/deploy/individual.Dockerfile .

docker run \
    -v /srv/external/:/srv/external/ \
    -v /var/log/shiny-server:/var/log/shiny-server \
    -p 3840:3840 \
    --name bivar-ext \
    bivar-ext