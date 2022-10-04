#!/usr/bin/env bash

export COMPOSE_FILE=./authoring/docker/docker-compose.yml

ACTION=$1

help () {
    echo "
    Commands

    up            Start the authoring environment
    down          Stop the authoring environment
    destroy       Stop the authoring environment and destroy all state.
    set-variant   Configure content variant used for preview
    reset-variant Reset variant used for preview to default
    "
}

if [ $# -eq 0 ]; then
    help
    echo "Please provide one of the valid commands."
    exit 1
fi

if [ $ACTION == "up" ]; then
    echo "Starting authoring environment"

    docker compose up --build -d
    docker compose exec moodle ./wait-for-it.sh postgres:5432 -- php admin/cli/install_database.php --agree-license --fullname="Local Dev" --shortname="Local Dev" --summary="Local Dev" --adminpass="admin" --adminemail="admin@acmeinc.com"
    docker compose exec postgres psql -U moodle -d moodle -c "update mdl_config set value='1' where name='forcelogin'"
    docker compose exec moodle php admin/cli/purge_caches.php
    bash  ./authoring/scripts/inject_additional_html.sh

    exit 0
fi

if [ $ACTION == "down" ]; then
    echo "Stoping authoring environment"

    docker compose down
    exit 0
fi

if [ $ACTION == "destroy" ]; then
    echo "Destroying authoring environment and state."

    read -p "Are you sure? All database state will be lost. Continue (y/n)? " -n 1 -r
    if [[ $REPLY =~ ^[Yy]$ ]]
    then
        docker compose down -v
    fi
    exit 0
fi

if [ $ACTION == "set-variant" ]; then
    VARIANT=$2

    if [[ -z $VARIANT ]]; then
        echo "Please provide a variant name"
        exit 1
    fi

    set -e

    sed 's/CONTENT_VARIANT=.*/CONTENT_VARIANT='$VARIANT'/' ./authoring/docker/.env > ./authoring/docker/.env.variant
    docker compose --env-file ./authoring/docker/.env.variant up --build -d

    exit 0
fi

if [ $ACTION == "reset-variant" ]; then
    set -e

    docker compose up --build -d

    exit 0
fi

help
echo "Invalid command. Please provide one of the valid commands."
exit 1