#! /bin/bash

#  This script pulls a previously exported mariadb docker volume (*.tar.gz) 
#+ from an aws s3 bucket, unpacks it to a given location and reinstantiates the
#+ database environment with a the given command line arguments.

# Maintainer: ddluke
# Last update date: 2017-07-05

#  Dependencies (later versions might work as well but have not been tested):
#+ docker version 17.03.2-ce
#+ docker-compose version 1.14.0
#+ python 2.7.5
#+ pip 9.0.1
#+ aws-cli/1.11.115
#
# Linux version and distribution this script has been tested on:
#+ Linux version 3.14.32
#+ CentOS Linux release 7.3.1611 (Core)


# Number of expected arguments
EXPECTED_ARGS=12

# Expected arguments, as displayed within usage
s3Bucket=
s3Path=
s3Object=
LocalPath=
mariadb_container_name=
mariadb_container_data_volume=
mariadb_container_confd_volume=
mariadb_container_confd_file=
mariadb_release=
mariadb_root_password=
mariadb_cpu_shares=
mariadb_memory_limit=



function usage {
# Function to display usage
    echo
    echo "Usage ${0##*/}:"
    echo "      [--s3Bucket] [--s3Path] [--s3Object] [--LocalPath]"
    echo "      [--mariadb_container_data_volume] [--mariadb_container_confd_volume]"
    echo "      [--mariadb_container_confd_file] [--mariadb_release] [--mariadb_root_password]"
    echo "      [--mariadb_cpu_shares] [--mariadb_memory_limit]"
    echo
    echo "--s3Bucket                        Name of the AWS S3 Bucket, the aws-cli will pull the MariaDB volume backup from."
    echo "--s3Path                          Path to the MariaDB volume backup"
    echo "--s3Object                        Name of the MariaDB volume backup"
    echo "--LocalPath                       Host path, where the MariaDB volume backup will be temporarily stored"    
    echo "--mariadb_container_name          This is the name your MariaDB container will be listed with using docker ps"
    echo "--mariadb_container_data_volume   If you specify /my/own/datadir as argument, the directory will be created"
    echo "                                  (if not already existing) and mounted from the underlying host system as"
    echo "                                  /var/lib/mysql inside the container, where MySQL by default will write its data files"
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
    echo
}

function loggError {
# Function to display a custom error message, call usage and exit with error
    echo "${0##*/} - ERROR: $1"
    usage
    exit 1
}

function loggDebug {
# Function to display a custom logg message for traceability
    echo "${0##*/} - DEBUG: $1"
}

if [ $# -ne $EXPECTED_ARGS ]
# Check if the number of given arguments equals $EXPECTED_ARGS and else run loggError and exit
    then 
        loggError "Invalid number of arguments provided!"
fi


while [ $# -gt 0 ]; do
# Parse command line arguments and exit on unknown argument, displaying usage
    case "$1" in
        
        --s3Bucket=*) s3Bucket=${1#*=} ;;
        --s3Path=*) s3Path=${1#*=} ;;
        --s3Object=*) s3Object=${1#*=} ;;
        --LocalPath=*) LocalPath=${1#*=} ;;
        --mariadb_container_name=*) mariadb_container_name=${1#*=} ;;
        --mariadb_container_data_volume=*) mariadb_container_data_volume=${1#*=} ;;
        --mariadb_container_confd_volume=*) mariadb_container_confd_volume=${1#*=} ;;
        --mariadb_container_confd_file=*) mariadb_container_confd_file=${1#*=} ;;
        --mariadb_release=*) mariadb_release=${1#*=} ;;
        --mariadb_root_password=*) mariadb_root_password=${1#*=} ;;
        --mariadb_cpu_shares=*) mariadb_cpu_shares=${1#*=} ;;
        --mariadb_memory_limit=*) mariadb_memory_limit=${1#*=} ;;
        *)
        loggError "Unkown Argument ${1/=*/}" 
    esac
    shift
done
loggDebug "All parameters successfully parsed"



# Initialize the directory, where the MariaDB volume backup will be temporarily stored and pull the 
# object from the specified bucket and path
loggDebug "Creating directory ${LocalPath}"

if [ -d ${LocalPath} ]
    then
        loggDebug "Path ${LocalPath} already exists"
    else
        mkdir -p ${LocalPath}
        loggDebug "${LocalPath} successfully created"
fi
exit 0
loggDebug "Copying s3://${s3Bucket}/${s3Path}/${s3Object} to ${LocalPath}"
aws s3 cp s3://${s3Bucket}/${s3Path}/${s3Object} ${LocalPath}




# Initialize the directory that will be mounted from the underlying host system as /var/lib/mysql 
# inside the container , where MySQL by default will write its data files
loggDebug "Creating directory ${mariadb_container_data_volume}"
if [ -d ${mariadb_container_data_volume} ]
    then
        loggDebug "Path ${mariadb_container_data_volume} already exists"
    else
        mkdir -p ${mariadb_container_data_volume}
        loggDebug "${mariadb_container_data_volume} successfully created"
fi
loggDebug "Unpacking ${LocalPath}/${s3Object} to ${DB_MYSQL_DATA_DIR}/.."
#tar -xf ${LocalPath}/${s3Object} -C ${DB_MYSQL_DATA_DIR}/..




# Initialize the directory where your my-config-file.cnf file be stored in. This directory will be
# mounted into the containers /etc/mysql/conf.d directory. This will make the created MariaDB instance
# use the combined startup settings from /etc/mysql/my.cnf and /etc/mysql/conf.d/config-file.cnf, 
# with settings from the latter taking precedence
loggDebug "Creating directory ${mariadb_container_confd_volume}"
if [ -d ${mariadb_container_confd_volume} ]
# Check wether ${mariadb_container_confd_volume} is a directory and create it if not existing
    then
        loggDebug "Path ${mariadb_container_confd_volume} already exists"
    else
        mkdir -p ${mariadb_container_confd_volume}
        loggDebug "${mariadb_container_confd_volume} successfully created"
fi

if [ ! -e ${mariadb_container_confd_file} ]
# Check wether ${mariadb_container_confd_file} exists and raise error if false
    then
        loggError "File ${mariadb_container_confd_file} does not exist or is not a file"
fi

if [ -s ${mariadb_container_confd_file} ]
# Check wether ${mariadb_container_confd_file} is not zero size and exit if false, else proceed and
# copy ${mariadb_container_confd_file} into ${mariadb_container_confd_volume}
    then
        loggDebug "Copying ${mariadb_container_confd_file} to ${mariadb_container_confd_volume}"
        cp ${mariadb_container_confd_file} ${mariadb_container_confd_volume}
    else
        loggError "File ${mariadb_container_confd_file} is zero size"
fi
 



# Pull the MariaDB image as specified within ${mariadb_release}
docker pull mariadb:${mariadb_release}
# Start up the container
docker run \
    --name=${mariadb_container_name} \
    -c ${mariadb_cpu_shares}\
    -m ${mariadb_memory_limit}\
    -v ${mariadb_container_data_volume}:/var/lib/mysql \
    -v ${mariadb_container_confd_volume}:/etc/mysql/conf.d \
    -e MYSQL_ROOT_PASSWORD=${mariadb_root_password}\
    -d \
    mariadb:${mariadb_release}

# Wait 5 seconds before checking wether the container is running
sleep 5

# Check if container is running an else display the containers log output
docker_container_status=$(docker inspect -f {{.State.Running}} ${mariadb_container_name})
echo ${docker_container_status}
if [ "${docker_container_status}" == "true" ]
    then
        echo "Container  ${mariadb_container_name} is up and running"
    else
        echo "Container ${mariadb_container_name} could not be started, displaying log output"
        docker logs ${mariadb_container_name}
        exit 1
fi




# Perform cleanup operations
loggDebug "Removing ${LocalPath}/${s3Object}"
# rm ${LocalPath}/${s3Object}
loggDebug "Removing ${LocalPath}"
# rm -r ${LocalPath}

exit 0
