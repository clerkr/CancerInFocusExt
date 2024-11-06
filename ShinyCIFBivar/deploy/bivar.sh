
docker build -t individual_bivar -f ShinyCIFBivar/deploy/individual.Dockerfile .

docker run \
    -v /srv/shiny-server/internal/:/srv/shiny-server/internal/ \
    -v /var/log/shiny-server:/var/log/shiny-server \
    -p 3840:3840 \
    individual_bivar