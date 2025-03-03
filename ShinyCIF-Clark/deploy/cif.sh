
#### Prod Env ####

# docker build -t cif-ext -f ShinyCIF/deploy/Dockerfile .

# docker run \
#     -v /srv/external:/srv/external \
#     -v /var/log/shiny-server:/var/log/shiny-server \
#     -p 3838:3838 \
#     cif-ext

#### Dev Env ###

docker build --platform linux/x86_64 -t cif-ext -f ShinyCIF/deploy/individual.Dockerfile .

docker run \
    -v /Users/davidstone/Projects/SHAPE/external:/srv/external \
    -v /var/log/shiny-server:/var/log/shiny-server \
    -p 3838:3838 \
    --name cif-ext \
    cif-ext