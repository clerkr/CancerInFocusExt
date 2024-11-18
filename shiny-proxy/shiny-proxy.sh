
docker run \
    -dv /srv/external:/srv/external \
    -v /var/log/shiny-proxy/:/var/log/shiny-proxy/ \
    -v /var/run/docker.sock:/var/run/docker.sock:ro \
    --group-add $(getent group docker | cut -d: -f3) \
    --net external-net \
    -p 8080:8080 \
    shiny-proxy-ext