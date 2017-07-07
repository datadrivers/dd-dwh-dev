#! /bin/bash

#  This script pulls a previously exported mariadb docker volume (*.tar.gz) 
#+ from an aws s3 bucket, unpacks it to a given location and reinstantiates the
#+ database environment with a the given command line arguments.

#  Maintainer: ddluke
#  Last update date: 2017-07-05

#  Dependencies (later versions might work as well but have not been tested):
#+ docker version 17.03.2-ce
#+ docker-compose version 1.14.0
#+ python 2.7.5
#+ pip 9.0.1
#+ aws-cli/1.11.115
#
#  Linux version and distribution this script has been tested on:
#+ Linux version 3.14.32
#+ CentOS Linux release 7.3.1611 (Core)


#  Number of expected arguments
EXPECTED_ARGS=8

#  Expected arguments, as displayed within usage
mariadb_container_name=
mariadb_container_confd_volume=
mariadb_container_confd_file=
mariadb_release=
mariadb_root_password=
mariadb_cpu_shares=
mariadb_memory_limit=
mariadb_access_port=



function usage {
#  Function to display usage
    echo
    echo "Usage ${0##*/}:"
    echo "      [--mariadb_container_confd_volume]"
    echo "      [--mariadb_container_confd_file] [--mariadb_release] [--mariadb_root_password]"
    echo "      [--mariadb_cpu_shares] [--mariadb_memory_limit]"
    echo
 
    echo "--mariadb_container_name          This is the name your MariaDB container will be listed with using docker ps"
    echo "--mariadb_container_confd_volume  If /my/custom/config-file.cnf is the path and name of your custom configuration file,"
    echo "                                  you would set it to /my/custom. This will make the created MariaDB instance"
    echo "                                  use the combined startup settings from /etc/mysql/my.cnf and"
    echo "                                  /etc/mysql/conf.d/config-file.cnf, with settings from the latter taking precedence"
    echo "--mariadb_container_confd_file    Specifies the location of a custom my-config-file.cnf. This file will be copied into " 
    echo "                                  the path specified within ${mariadb_container_confd_volume}"
    echo "--mariadb_release                 This is the tag of the MariaDB image you wish to pull, for instance 10.3, 10.2, latest ..."
    echo "--mariadb_root_password           This variable will be associated with the MariaDB environment variable MYSQL_ROOT_PASSWORD."
    echo "--mariadb_cpu_shares              CPU shares (relative weight)"
    echo "--mariadb_memory_limit            Memory limit"
    echo "--mariadb_access_port             Defines which host port will point to container port 3306"
    echo
}

#  Declare function to unify ERROR log outputs
function logError {
    echo
    echo "${0##*/} - ERROR: $1"
    usage
    exit 1
}

#  Declare function to unify DEBUG log outputs
function logDebug {
    echo "${0##*/} - DEBUG: $1"
}

#  Check if the correct number of arguments has been given
if [ $# -ne $EXPECTED_ARGS ]
then 
    logError "Invalid number of arguments provided!"
fi


#  Parse command line arguments
while [ $# -gt 0 ]; do
    case "$1" in
        --mariadb_container_name=*) mariadb_container_name=${1#*=} ;;
        --mariadb_container_confd_volume=*) mariadb_container_confd_volume=${1#*=} ;;
        --mariadb_container_confd_file=*) mariadb_container_confd_file=${1#*=} ;;
        --mariadb_release=*) mariadb_release=${1#*=} ;;
        --mariadb_root_password=*) mariadb_root_password=${1#*=} ;;
        --mariadb_cpu_shares=*) mariadb_cpu_shares=${1#*=} ;;
        --mariadb_memory_limit=*) mariadb_memory_limit=${1#*=} ;;
        --mariadb_access_port=*) mariadb_access_port=${1#*=} ;;
        *)
        logError "Unkown Argument ${1/=*/}" 
    esac
    shift
done
logDebug "All parameters successfully parsed"




################################################################
#
#    Check if container already exist and exit if true
#
################################################################

#  Check if the MariaDB data container is running
if [ "$(docker ps -aq -f status=running -f name=${mariadb_container_name})" ]
then
    logError "container ${mariadb_container_name} has already been created. Please make sure to specify unique container names"
fi

#  Check if the MariaDB database container has been created
if [ "$(docker ps -aq -f status=created -f name=${mariadb_container_name}_data)" ]
then
    logError "container ${mariadb_container_name}_data already exists. Please make sure to specify unique container names"
fi




################################################################
#
#    Initialize directories and files
#
################################################################

logDebug "Creating directory ${mariadb_container_confd_volume}"
if [ -d ${mariadb_container_confd_volume} ]
then
    logDebug "Path ${mariadb_container_confd_volume} already exists"
else
    mkdir -p ${mariadb_container_confd_volume}
    logDebug "${mariadb_container_confd_volume} successfully created"
fi

if [ ! -e ${mariadb_container_confd_file} ]
then
    logError "File ${mariadb_container_confd_file} does not exist or is not a file"
fi

if [ -s ${mariadb_container_confd_file} ]
then
    logDebug "Copying ${mariadb_container_confd_file} to ${mariadb_container_confd_volume}"
    cp ${mariadb_container_confd_file} ${mariadb_container_confd_volume}
else
    logError "File ${mariadb_container_confd_file} is zero size"
fi




################################################################
#
#    Create the MariaDB data container
#
################################################################

#  Create the MariaDB data container
#docker create -v /${mariadb_container_name} --name ${mariadb_container_name}_data alpine:latest /bin/true

#  Check if the MariaDB data container has been successfully created
if [ "$(docker inspect -f {{.State.Status}} ${mariadb_container_name}_data)" == "created" ]
then
    logDebug "Container  ${mariadb_container_name}_data has successfully been created"
else
    echo "Container ${mariadb_container_name}_data could not be created, displaying log output:"
    docker logs ${mariadb_container_name}
    exit 1
fi




################################################################
#
#    Create the MariaDB database container
#
################################################################

#  Create the MariaDB database container
#docker run \
    -d \
    -c ${mariadb_cpu_shares} \
    -m ${mariadb_memory_limit} \
    --name=${mariadb_container_name} \
    --publish ${mariadb_access_port}:3306 \
    --volumes-from ${mariadb_container_name}_data \
    --volume ${mariadb_container_confd_volume}:/etc/mysql/conf.d/ \
    -e MYSQL_ROOT_PASSWORD=${mariadb_root_password} \
    mariadb:${mariadb_release}

#  Delay the following container status check in case the database is not instantly up and running
sleep 5

#  Check if the MariaDB database container has been successfully started
if [ "$(docker inspect -f {{.State.Running}} ${mariadb_container_name})" == "true" ]
then
    logDebug "Container  ${mariadb_container_name} is up and running"
else
    echo "Container ${mariadb_container_name} could not be started. It's current status is $(docker inspect -f {{.State.Status}} ${mariadb_container_name})" 
    docker logs ${mariadb_container_name}
    exit 1
fi


logDebug "Execution Succeeded"

exit 0