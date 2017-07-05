#! /bin/bash

#  This script pulls a previously exported mariadb docker volume (*.tar.gz) 
#+ from an aws s3 bucket, unpacks it to a given location and reinstantiates the
#+ database environment with a given docker-compose.yml file

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
EXPECTED_ARGS=9

# Used variables
s3Bucket=
s3Path=
s3Object=
LocalPath=
dockerComposeYml=
DB_MYSQL_ROOT_PASSWORD=
DB_MYSQL_DATA_DIR=
DB_MYSQL_CONFD_DIR=
DB_MYSQL_MY_CNF_FILE=


function usage {
# Function to display usage and exit with error
    echo
    echo "Usage: $0 "
    echo "      [--s3Bucket=some-name]"
    echo "      [--s3Path=/some/path/to/s3object]"
    echo "      [--s3Object=s3object]"
    echo "      [--LocalPath=/some/path]"
    echo "      [--dockerComposeYml=/path/to/file]"
    echo "      [--DB_MYSQL_ROOT_PASSWORD=mysecret]"
    echo "      [--DB_MYSQL_DATA_DIR]=/some/path]"
    echo "      [--DB_MYSQL_CONFD_DIR]=/some/path]"
    echo "      [--DB_MYSQL_MY_CNF_FILE]=/path/to/my.cnf]"
    echo
    echo "      --s3Bucket                  AWS S3 bucket name"
    echo "      --s3Path                    Path to an AWS-S3 *.tar.gz object that holds the volume backup"
    echo "      --s3Object                  Name of the AWS-S3 *.tar.gz object that holds the volume backup"
    echo "      --LocalPath                 Path the s3Object will be stored in"
    echo "      --dockerComposeYml          Path to your docker-compose.yml file. It should contain"
    echo "                                  the variables DB_MYSQL_ROOT_PASSWORD, DB_MYSQL_DATA_DIR, DB_MYSQL_CONFD_DIR"
    echo "                                  which will be replace with the values passed to the script"
    echo "      --DB_MYSQL_ROOT_PASSWORD    MYSQL_ROOT_PASSWORD associated to the mariadb root user."
    echo "                                  Wrap your password in single quotes if it contains special characaters."
    echo "                                  The '&'-sign needs to be manually escaped using backslash"
    echo "      --DB_MYSQL_DATA_DIR         Path to your hosts mariadb data dir, container data is persisted to"
    echo "      --DB_MYSQL_CONFD_DIR        Path to a directory that holds a custom my.conf file"
    echo "                                  which will be mounted into the containers data dir at "
    echo "                                  /etc/mysql/conf.d"
    echo "      --DB_MYSQL_MY_CNF_FILE      Valid Path/to/my.cnf which will be mounted into DB_MYSQL_CONFD_DIR"
    echo
    exit 1

}

function loggError {
  echo "ERROR\: $0, Line ${LINENO}\: $1"
}

function loggDebug {
  echo "DEBUG\: $0, Line ${LINENO}\: $1"
}



if [ $# -ne $EXPECTED_ARGS ]
# Check for proper number of command-line args.
    then 
    echo
    loggError "Invalid number of arguments provided!"
    usage
    exit $E_BADARGS
fi


while [ $# -gt 0 ]; do
# Parse command line arguments and exit on unknown argument, displaying usage
    case "$1" in
        --s3Bucket=*) s3Bucket=${1#*=} ;;
        --s3Path=*) s3Path=${1#*=} ;;
        --s3Object=*) s3Object=${1#*=} ;;
        --LocalPath=*) LocalPath=${1#*=} ;;
        --dockerComposeYml=*) dockerComposeYml=${1#*=} ;;
        --DB_MYSQL_ROOT_PASSWORD=*) DB_MYSQL_ROOT_PASSWORD=${1#*=} ;;
        --DB_MYSQL_DATA_DIR=*) DB_MYSQL_DATA_DIR=${1#*=} ;;
        --DB_MYSQL_CONFD_DIR=*) DB_MYSQL_CONFD_DIR=${1#*=} ;;
        --DB_MYSQL_MY_CNF_FILE=*) DB_MYSQL_MY_CNF_FILE=${1#*=} ;;
        *)
        echo
        loggError "Unkown Argument ${1/=*/}" 
        usage
        exit $E_BADARGS
    esac
    shift
done
loggDebug "All parameters successfully parsed"


loggDebug "Creating directory ${LocalPath} if not existing and copy ${s3Object} from aws s3 to ${LocalPath}"
mkdir -p ${LocalPath}
loggDebug "Copying s3://${s3Bucket}/${s3Path}/${s3Object} to ${LocalPath}"
aws s3 cp s3://${s3Bucket}/${s3Path}/${s3Object} ${LocalPath}


loggDebug "'sed' replace \$DB_MYSQL_ROOT_PASSWORD, \$DB_MYSQL_DATA_DIR and \$DB_MYSQL_CONFD_DIR within ${dockerComposeYml}"
sed -i s+DB_MYSQL_ROOT_PASSWORD+${DB_MYSQL_ROOT_PASSWORD}+g ${dockerComposeYml}
sed -i s+DB_MYSQL_DATA_DIR+${DB_MYSQL_DATA_DIR}+g ${dockerComposeYml}
sed -i s+DB_MYSQL_CONFD_DIR+${DB_MYSQL_CONFD_DIR}+g ${dockerComposeYml}


loggDebug "Creating directory ${DB_MYSQL_DATA_DIR}"
mkdir -p ${DB_MYSQL_DATA_DIR}
loggDebug "Unpacking ${LocalPath}/${s3Object} to ${DB_MYSQL_DATA_DIR}"
tar -xf ${LocalPath}/${s3Object} -C ${DB_MYSQL_DATA_DIR}/..


loggDebug "Creating directory ${DB_MYSQL_CONFD_DIR}"
mkdir -p ${DB_MYSQL_CONFD_DIR}
loggDebug "Copying ${DB_MYSQL_MY_CNF_FILE} to ${DB_MYSQL_CONFD_DIR}"
cp ${DB_MYSQL_MY_CNF_FILE} ${DB_MYSQL_CONFD_DIR}


loggDebug "Starting servies as specified within ${dockerComposeYml}"
docker-compose -f ${dockerComposeYml} up -d


loggDebug "Removing ${dockerComposeYml}"
rm ${dockerComposeYml}
loggDebug "Removing ${DB_MYSQL_MY_CNF_FILE}"
rm ${DB_MYSQL_MY_CNF_FILE}
loggDebug "Removing ${LocalPath}/${s3Object}"
rm ${LocalPath}/${s3Object}
#loggDebug "Removing ${LocalPath}"
# rm -r ${LocalPath}

exit 0
