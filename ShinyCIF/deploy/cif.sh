
docker build -t cif -f ShinyCIF/deploy/Dockerfile .

docker run \
    -v /srv/external:/srv/external \
    -v /var/log/shiny-server:/var/log/shiny-server \
    -p 3838:3838 \
    cif