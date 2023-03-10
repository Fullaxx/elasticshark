# ------------------------------------------------------------------------------
# Pull base image
FROM fullaxx/elastibana
MAINTAINER Brett Kuskie <fullaxx@gmail.com>

# ------------------------------------------------------------------------------
# Copy our project configuration
COPY autoconfig /elasticsearch/autoconfig
