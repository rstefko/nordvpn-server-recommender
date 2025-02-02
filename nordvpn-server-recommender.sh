#!/bin/env sh
# NordVPN Server Recommender
# Returns the top 5 recommended NordVPN servers based on your
# geographic location and current server loads using the api at
# https://nordvpn.com/servers/tools/
# Requires jq and curl
# Natan Vargas (https://github.com/nvarg)

set -e

nordvpn_api() {
    curl -sg "https://nordvpn.com/wp-admin/admin-ajax.php?action=servers_$1" |
        jq --arg val "$2" -r '.[] | [.id, .[$val]] | @tsv'
}

nordvpn_remote_print() {
    curl -sg "https://nordvpn.com/wp-admin/admin-ajax.php?action=servers_recommendations$1" |
        jq -r '.[] | ["remote " + .hostname + " 1194 # " + .station] | @tsv'
}

get_opt() {
    if echo "$2" | cut -f 2 | grep -Fqx "$1"; then
        echo "$2" | awk -v c="$1" 'BEGIN{FS="\t";}{if(c==$2){print$1}}'
    fi
}

requires() {
    if ! [ -x "$(command -v $1)" ]; then
        echo "Error: $0 requires $1, but it is not installed." >&2
        echo "Error: Aborting." >&2
        exit 1
    fi
}

usage() {
    echo "usage: $0 [-hu] [-c <country code>] [-t <technology>] [-g <group>]"
}

help() {
    usage
    echo
    {
       echo "-c <country code>:only recommends servers located in that country"
       echo "-c list:displays a list of the available country codes"
       echo ":"
       echo "-t <technology name>:only recommends servers with that technology available."
       echo "-t list:displays a list of the available technologies"
       echo ":"
       echo "-g <group identfier>:only recommends servers in that group"
       echo "-g list:displays a list of the available group identifiers"
       echo ":"
       echo "-u:displays usage"
       echo ":"
       echo "-h:displays this help menu"
    } | column -t -s :
}

requires curl >/dev/null
requires jq >/dev/null

country='null'
technology='null'
group='null'

while getopts "uhc:t:g:" opt; do
    case $opt in
        c)
            filter_bool=1
            if [ "$OPTARG" = 'list' ]; then
                nordvpn_api countries code | cut -f 2 | fmt
                exit 0
            else
                country="$(get_opt "$OPTARG" "$(nordvpn_api countries code)")"
                if [ "$country" = "" ]; then
                    echo "ERROR: $OPTARG is not a valid country code. Run '$0 -c list' to list the available country codes" >&2
                    exit 1
                fi
            fi
            ;;
        t)
            filter_bool=1
            if [ "$OPTARG" = 'list' ]; then
                nordvpn_api technologies name | cut -f 2
                exit 0
            else
                technology="$(get_opt "$OPTARG" "$(nordvpn_api technologies name)")"
                if [ "$technology" = "" ]; then
                    echo "ERROR: $OPTARG is not a valid technology name. Run '$0 -t list' to list the available technology names" >&2
                    exit 1
                fi
            fi
            ;;
        g)
            filter_bool=1
            if [ "$OPTARG" = 'list' ]; then
                nordvpn_api groups identifier | cut -f 2 | fmt
                exit 0
            else
                group="$(get_opt "$OPTARG" "$(nordvpn_api groups identifier)")"
                if [ "$group" = "" ]; then
                    echo "ERROR: $OPTARG is not a valid group identifier. Run '$0 -g list' to list the available group identifiers" >&2
                    exit 1
                fi
            fi
            ;;
        u)
            usage
            exit 0
            ;;
        h)
            help
            exit 0
            ;;
    esac
done


if [ "$filter_bool" = 1 ]; then
    filter="&filters=""$(jq -cn \
        --argjson country "$country" \
        --argjson technology "$technology" \
        --argjson group "$group" \
        '{"country_id":$country,"servers_technologies":[$technology],"servers_groups":[$group]}
            | [ to_entries[] | select(.value != null and .value != [null]) ]
            | from_entries')"
fi

nordvpn_remote_print $filter
