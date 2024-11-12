
docker build -t profiles-ext -f ShinyCIFProfiles/deploy/Dockerfile .

docker run \
    -dv /srv/external/:/srv/external/ \
    -v /var/log/shiny-server:/var/log/shiny-server \
    -p 3839:3839 \
    profiles-ext