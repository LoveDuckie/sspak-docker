ARG CUSTOM_BUILD_VERSION development
ARG CUSTOM_TIMEZONE "Europe/London"

FROM php:7.4.23-cli-alpine as php-builder

LABEL maintainer="Luc \"LoveDuckie\" Shelton <lucshelton@gmail.com>" \
      org.label-schema.schema-version="1.0" \
      org.label-schema.build-date=$CUSTOM_BUILD_DATE \ 
      org.label-schema.name="loveduckie/sspak-docker" \
      org.label-schema.url="https://www.lucshelton.com" \
      org.label-schema.description="Docker container for SSPAK tool" \
      org.label-schema.version=${CUSTOM_BUILD_VERSION}

ARG CUSTOM_BUILD_VERSION development
# RUN echo https://dl-cdn.alpinelinux.org/alpine/edge/community/ >>/etc/apk/repositories

#
#   INSTALL: ALPINE PACKAGES
#
RUN apk update

RUN apk add --no-cache tzdata
ENV TZ=Europe/London
RUN cp /usr/share/zoneinfo/$TZ /etc/localtime

RUN apk add --no-cache --update 'mariadb-client>10.3.15' \
    git openssh mariadb-connector-c bash shadow openssl freetype-dev libjpeg-turbo-dev libpng-dev \
    icu icu-libs icu-dev \
    && rm -rf /var/cache/apk/*

RUN mkdir -p /etc/sudoers.d/ && touch /etc/sudoers.d/$(whoami)
RUN echo "$(whoami) ALL=(ALL:ALL) NOPASSWD:ALL" | tee -a /etc/sudoers.d/$(whoami)
    
#
#   INSTALL: COMPOSER
#
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer
RUN chmod +x /usr/local/bin/composer

#
#   INSTALL: SSPAK
#
# RUN curl -sS https://silverstripe.github.io/sspak/install | php -- /usr/local/bin
RUN mkdir -p ~/.ssh/ && touch ~/.ssh/known_hosts && ssh-keyscan -H github.com >> ~/.ssh/known_hosts
RUN ssh-keygen -o -t rsa -N '' -f ~/.ssh/id_rsa -C "ssh@github.com"
RUN mkdir -p /sspak
RUN eval `ssh-agent` && ssh-add && git clone https://github.com/silverstripe/sspak.git /sspak
RUN cd /sspak && git checkout 1d1ffff9af48b4ebd6d133830c325244e201695d
RUN chmod ug+rwx /sspak
RUN cd /sspak && cat bin/install | php -- /usr/local/bin

# Images
RUN docker-php-ext-configure gd && docker-php-ext-install gd

# i18n
RUN docker-php-ext-configure intl && docker-php-ext-install intl

RUN mkdir -p /scripts

# BUILD VERSION: DEVELOPMENT

FROM php-builder as portfolio-sspak-docker-development

RUN apk add nano sudo

# BUILD VERSION: PRODUCTION

FROM php-builder as portfolio-sspak-docker-production

FROM portfolio-sspak-docker-${CUSTOM_BUILD_VERSION} as portfolio-sspak-docker-version

COPY ./containers/sspak-docker/scripts/*.sh /scripts

RUN mkdir -p /var/log/backups
RUN chmod -R ug+rwx /scripts /var/log/backups

ENTRYPOINT ["/scripts/sspak-docker-entrypoint.sh"]