#!/usr/bin/env bash

repository=${repository:-$1}
registry=${registry:-docker.io}

echo "repository => ${repository}"
echo "registry => ${registry}"

#
#  Docker functions
#
__docker_relative_repository_name_from_URL() {
    # given $registry/repo/path:tag, return the repo/path
    set +o pipefail
    echo ${1-} |
    sed -e "s|^$registry/||" |
    cut -d: -f1
}

__version_sort() {
    # read stdin, sort by version number descending, and write stdout
    # assumes X.Y.Z version numbers

    # this will sort tags like pr-3001, pr-3002 to the END of the list
    # and tags like 2.1.4 BEFORE 2.1.4-gitsha
    sort -s -t- -k 2, 2nr |
    sort -t. -s -k 1, 1nr -k 2, 2nr -k 3, 3nr -k 4, 4nr
}

__basic_auth() {
    #
    # read basic auth credentials from `docker login`
    #
    cat ~/.docker/config.json |
    json '.auths["https://index.docker.io/v1/"].auth'
}

__registry__tags_list() {
    # return a list of available tags for the given repository sorted
    # by version number, descending
    #
    # Get tags list from dockerhub using v2 api and an auth.docker token

    local rel_repository=$(__docker_relative_repository_name_from_URL ${1})
    [ -z "$rel_repository" ] && return

    local TOKEN=$(curl -s -H "Authorization: Basic $(__basic_auth)" \
                    -H 'Accept: application/json' \
                    "https://auth.docker.io/token?service=registry.docker.io&scope=repository:$rel_repository:pull" |
                    json .token)

    curl -s -H "Authorization: Bearer $TOKEN" -H "Accept: application/json" \
            "https://index.docker.io/v2/$rel_repository/tags/list" |
            json .tags |
            json -a |
            __version_sort
}

__registry__tags_list $repository
