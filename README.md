# Laravel from dev to prod

**Goal**: build laravel docker image optimized from production but compatible for development based on the template provided by [https://laravel.build/](https://laravel.build/) without sail.

## Goals



## Prerequisites

Tested on Ubuntu 20.04 with the following tools :

```shell
$ docker version
Client: Docker Engine - Community
 Version:           20.10.6
[...]
$ docker-compose version
docker-compose version 1.29.1, build c34c88b2
[...]
```

## Development

```shell
git clone git@github.com:kartoch/laravel-from-dev-to-prod.git
cd laravel-from-dev-to-prod
docker-compose build
docker-compose up
docker exec -it laravel-from-dev-to-prod_laravel_1 composer install
```

By default, Laravel application is available in port 80.

The node image install the dependencies at startup if not present, so except few seconds or minutes before mix dependencies are available.

## Production

Build the image for production :

```shell
docker buildx build -t laravel-from-dev-to-ops .
```

The build includes :

- using php docker images and enable required php extensions
- building the mix resources from node image and copy them inside laravel image
- install laravel resources (without dev dependencies) using composer
- start phpunit

## TODO

- [ ] Switch to PHP FPM
