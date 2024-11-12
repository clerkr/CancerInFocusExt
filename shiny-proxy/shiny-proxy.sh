
docker build -t cif-ext -f ShinyCIF/deploy/Dockerfile .
docker build -t profiles-ext -f ShinyCIFProfiles/deploy/Dockerfile .
docker build -t bivar-ext -f ShinyCIFBivar/deploy/Dockerfile .

# sh ShinyCIF/deploy/cif.sh
# sh ShinyCIFProfiles/deploy/profiles.sh
# sh ShinyCIFBivar/deploy/bivar.sh

docker build -t shiny-proxy-ext -f shiny-proxy/Dockerfile .

docker run \
    -v /srv/external:/srv/external \
    -v /var/log/shiny-proxy/:/var/log/shiny-proxy/ \
    -v /var/run/docker.sock:/var/run/docker.sock:ro \
    --group-add $(getent group docker | cut -d: -f3) \
    --net external-net \
    -p 8080:8080 \
    shiny-proxy-ext