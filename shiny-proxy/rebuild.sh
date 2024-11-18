
docker build -t cif-ext -f ShinyCIF/deploy/Dockerfile .
docker build -t profiles-ext -f ShinyCIFProfiles/deploy/Dockerfile .
docker build -t bivar-ext -f ShinyCIFBivar/deploy/Dockerfile .

docker build -t shiny-proxy-ext -f shiny-proxy/Dockerfile .