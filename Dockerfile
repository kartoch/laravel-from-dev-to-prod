ARG COMPOSER_DOCKER_TAG=2.0.13
ARG NODE_DOCKER_TAG=15.14.0-buster
ARG PHP_DOCKER_TAG=8.0.6-apache-buster

FROM node:${NODE_DOCKER_TAG} as node-base

WORKDIR /home/node/app

FROM node-base as node-prod

COPY package.json .

RUN npm install

COPY webpack.mix.js .
ADD resources/ resources/

RUN npm run prod

FROM node-base as node-dev

VOLUME /home/node/app

CMD ["npm","run","watch"]

COPY docker/node-entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]

FROM composer:${COMPOSER_DOCKER_TAG} as composer

FROM php:8.0.6-apache-buster AS php-base

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
                       default-mysql-client postgresql-client gosu curl ca-certificates zip unzip git sqlite3 && \
    docker-php-ext-configure imap --with-kerberos --with-imap-ssl && \
    docker-php-ext-install -j$(nproc) pdo_mysql zip pgsql gd curl imap mysqli mbstring xml zip bcmath soap intl readline ldap && \
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

COPY docker/000-default.conf /etc/apache2/sites-available/

RUN a2enmod negotiation && a2enmod rewrite

WORKDIR /var/www/html/

FROM php-base AS php-dev

VOLUME /var/www/html/

RUN mv "$PHP_INI_DIR/php.ini-development" "$PHP_INI_DIR/php.ini"

COPY docker/laravel-entrypoint.sh /entrypoint.sh

CMD ["apache2-foreground"]

ENTRYPOINT ["/entrypoint.sh"]

FROM php-base AS php-test

COPY artisan .
COPY app/ app/
COPY bootstrap/ bootstrap/
COPY config/ config/
COPY database/ database/
COPY public/ public/
COPY resources/ resources/
COPY routes/ routes/
COPY server.php .

COPY tests/ tests/
COPY phpunit.xml .

COPY .env.testing .

COPY --from=node-prod  /home/node/app/public/js/ public/js/
COPY --from=node-prod  /home/node/app/public/css/ public/css/

RUN composer install

RUN mkdir -p /var/www/html/storage/logs/ && \
    mkdir -p /var/www/html/storage/app/public/ && \
    mkdir -p /var/www/html/storage/framework/cache/data/ && \
    mkdir -p /var/www/html/storage/framework/sessions/ && \
    mkdir -p /var/www/html/storage/framework/testing/ && \
    mkdir -p /var/www/html/storage/framework/views/ && \
    chown -R www-data:www-data /var/www/html/storage/ && \
    chmod -R 700 /var/www/html/storage/

RUN ./vendor/bin/phpunit

FROM php-base AS php-prod

RUN mv "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini"

COPY artisan .
COPY app/ app/
COPY bootstrap/ bootstrap/
COPY config/ config/
COPY database/ database/
COPY public/ public/
COPY resources/ resources/
COPY routes/ routes/
COPY server.php .

COPY composer.json .
COPY composer.lock .

COPY --from=node-prod  /home/node/app/public/js/ public/js/
COPY --from=node-prod  /home/node/app/public/css/ public/css/

RUN rm -rf vendor/ && composer install --no-dev

RUN mkdir -p /var/www/html/storage/logs/ && \
    mkdir -p /var/www/html/storage/app/public/ && \
    mkdir -p /var/www/html/storage/framework/cache/data/ && \
    mkdir -p /var/www/html/storage/framework/sessions/ && \
    mkdir -p /var/www/html/storage/framework/testing/ && \
    mkdir -p /var/www/html/storage/framework/views/ && \
    chown -R www-data:www-data /var/www/html/storage/ && \
    chmod -R 700 /var/www/html/storage/
