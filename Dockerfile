ARG COMPOSER_DOCKER_TAG=2.0.13
ARG NODE_DOCKER_TAG=15.14.0-buster
ARG PHP_DOCKER_TAG=8.0.6-fpm-buster
ARG NGINX_DOCKER_TAG=1.20.1

FROM composer:${COMPOSER_DOCKER_TAG} AS composer

FROM php:${PHP_DOCKER_TAG} AS php-root

LABEL maintainer="Julien Cartigny <kartoch@gmail.com>"

COPY --from=composer /usr/bin/composer /usr/bin/composer

ARG MEMCACHED_PECL_VERSION=3.1.5
ARG MSGPACK_PECL_VERSION=2.1.2
ARG IGBINARY_PECL_VERSION=3.2.2
ARG REDIS_PECL_VERSION=5.3.4
ARG SWOOLE_PECL_VERSION=4.6.7

RUN apt-get update && \
    apt-get install -y libxml2-dev zlib1g-dev libedit-dev libldb-dev libldap2-dev libzip-dev libmemcached-dev \
                       zlib1g-dev libpq-dev libpng-dev libkrb5-dev libonig-dev libcurl4-openssl-dev libc-client-dev \
                       default-mysql-client postgresql-client gosu curl ca-certificates zip unzip git && \
    docker-php-ext-configure pdo_mysql --with-pdo-mysql=mysqlnd && \
    docker-php-ext-configure mysqli --with-mysqli=mysqlnd && \
    docker-php-ext-configure imap --with-kerberos --with-imap-ssl && \
    docker-php-ext-install -j$(nproc) pdo_mysql zip pgsql gd curl imap mysqli mbstring xml zip bcmath soap intl \
                                      readline ldap && \
    pecl channel-update https://pecl.php.net/channel.xml && \
    pecl install memcached-$MEMCACHED_PECL_VERSION && \ 
    pecl install msgpack-$MSGPACK_PECL_VERSION && \
    pecl install igbinary-$IGBINARY_PECL_VERSION && \
    pecl install redis-$REDIS_PECL_VERSION && \
    pecl install swoole-$SWOOLE_PECL_VERSION && \
    docker-php-ext-enable redis memcached msgpack igbinary swoole && \
    pecl clear-cache && \    
    apt-get -y autoremove && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

RUN echo 'chdir = /var/www/html/public' >> /usr/local/etc/php-fpm.d/www.conf 

WORKDIR /var/www/html/

FROM php-root AS php-dev

RUN mv "$PHP_INI_DIR/php.ini-development" "$PHP_INI_DIR/php.ini"

#COPY docker/laravel-entrypoint.sh /entrypoint.sh

#ENTRYPOINT ["/entrypoint.sh"]

FROM php-root AS php-base

COPY . .

RUN mkdir -p /var/www/html/storage/logs/ && \
    mkdir -p /var/www/html/storage/app/public/ && \
    mkdir -p /var/www/html/storage/framework/cache/data/ && \
    mkdir -p /var/www/html/storage/framework/sessions/ && \
    mkdir -p /var/www/html/storage/framework/testing/ && \
    mkdir -p /var/www/html/storage/framework/views/ && \
    chown -R www-data:www-data /var/www/html/storage/ && \
    chmod -R 700 /var/www/html/storage/ && \
    mkdir -p /var/www/html/bootstrap/cache/ && \
    chown -R www-data:www-data /var/www/html/bootstrap/cache/

RUN mv "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini"

FROM php-base AS php-test

COPY .env.testing .env

RUN composer install

RUN ./vendor/bin/phpunit

FROM php-base AS php-prod

COPY .env.production .env

RUN composer install --no-dev

FROM node:${NODE_DOCKER_TAG} AS node-base

WORKDIR /home/node/app

FROM node-base AS node-prod

COPY --from=php-prod /var/www/html/ /home/node/app/

RUN npm install

RUN npm run production

FROM node-base AS node-dev

COPY docker/node-entrypoint.sh /entrypoint.sh

CMD ["npm","run","watch"]

ENTRYPOINT ["/entrypoint.sh"]

FROM nginx:${NGINX_DOCKER_TAG} AS nginx-base

RUN rm /usr/share/nginx/html/*

FROM nginx-base AS nginx-prod

COPY --from=node-prod  /home/node/app/public/ /usr/share/nginx/html/

# XXX : using nginx conf from dev env
COPY docker/nginx.conf.template /etc/nginx/templates/default.conf.template

FROM nginx:${NGINX_DOCKER_TAG} AS nginx-dev

# XXX : using nginx conf from dev env
COPY docker/nginx.conf.template /etc/nginx/templates/default.conf.template
