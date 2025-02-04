
#### Prod Env ####

# docker build -t access-ext -f ShinyCIFAccess/deploy/Dockerfile .

# docker run \
#     -v /srv/external/:/srv/external/ \
#     -v /var/log/shiny-server:/var/log/shiny-server \
#     -p 3841:3841 \
#     access-ext

#### Dev Env ####

docker build --platform linux/x86_64 -t access-ext -f ShinyCIFAccess/deploy/individual.Dockerfile .

docker run \
    -v /srv/external/:/srv/external/ \
    -v /var/log/shiny-server:/var/log/shiny-server \
    -p 8080:8080 \
    --name access-ext \
    access-ext