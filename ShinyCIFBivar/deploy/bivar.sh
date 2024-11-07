
docker build -t individual_bivar -f ShinyCIFBivar/deploy/individual.Dockerfile .

docker run \
    -v /srv/external/:/srv/external/ \
    -v /var/log/shiny-server:/var/log/shiny-server \
    -p 3840:3840 \
    individual_bivar