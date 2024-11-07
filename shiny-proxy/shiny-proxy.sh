
docker build -t cif -f ShinyCIF/deploy/Dockerfile .
docker build -t profiles -f ShinyCIFProfiles/deploy/Dockerfile .
docker build -t bivar -f ShinyCIFBivar/deploy/Dockerfile .

# sh ShinyCIF/deploy/cif.sh
# sh ShinyCIFProfiles/deploy/profiles.sh
# sh ShinyCIFBivar/deploy/bivar.sh

docker build -t shiny-proxy -f shiny-proxy/Dockerfile .

docker run \
    -v /srv/external:/srv/external \
    -v /var/run/docker.sock:/var/run/docker.sock:ro \
    --group-add $(getent group docker | cut -d: -f3) \
    --net external-net \
    -p 8080:8080 \
    shiny-proxy