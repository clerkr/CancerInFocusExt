
docker build -t nav -f nav/Dockerfile .

docker run \
    -v /srv/shiny-server/internal/:/srv/shiny-server/internal/ \
    -v /var/log/shiny-server:/var/log/shiny-server \
    -p 3841:3841 \
    nav