
docker build -t cif -f ShinyCIF/deploy/Dockerfile .

docker run \
    -v /srv/shiny-server/internal/:/srv/shiny-server/internal/ \
    -v /var/log/shiny-server:/var/log/shiny-server \
    -p 3838:3838 \
    cif