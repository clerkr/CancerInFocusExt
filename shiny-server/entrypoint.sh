#!/bin/bash
# Set permissions
setfacl -R -m u:shiny:rwx /srv/shiny-server/internal/

# Start Shiny Server
exec shiny-server