
docker build -t profiles -f ShinyCIFProfiles/deploy/Dockerfile .

docker run \
    -dv /srv/shiny-server/internal/:/srv/shiny-server/internal/ \
    -v /var/log/shiny-server:/var/log/shiny-server \
    -p 3839:3839 \
    profiles