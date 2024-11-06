#!/bin/bash
# Set permissions
setfacl -R -m u:shiny:rwx /srv/shiny-server/internal/

# Start Shiny Proxy
java -jar shinyproxy-3.0.2.jar