#!/bin/bash

################################################################
#
#    variable definition
#
################################################################

# get latest docker compose released tag
if [ $2 ]
then
    COMPOSE_VERSION=$2
else
    COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep 'tag_name' | cut -d\" -f4)
fi

# docker admin user name
DOCKER_ADMIN_USER=docker-admin


################################################################
#
#    basic software installation
#
################################################################

# install required packages
yum install -y \
		device-mapper-persistent-data \
		git \
		lvm2 \
		yum-utils

# add CentOS Docker repository 
yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo

# update yum package index
yum makecache fast

# get (particular) docker CE from repository 
if [ $1 ]
then
    yum install -y docker-ce-$1
else
    yum install -y docker-ce
fi

# start docker
systemctl start docker

# install docker-compose
curl -L https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-`uname -s`-`uname -m` > /usr/local/bin/docker-compose

# make docker-compose executable
chmod +x /usr/local/bin/docker-compose


################################################################
#
#    create docker-admin
#
################################################################

# create docker-admin user and assign to docker group
useradd -m -G docker ${DOCKER_ADMIN_USER}

# make root admin docker-admin as well
mkdir /home/${DOCKER_ADMIN_USER}/.ssh/
cp ~/.ssh/authorized_keys2 /home/${DOCKER_ADMIN_USER}/.ssh/
chown -R ${DOCKER_ADMIN_USER}:${DOCKER_ADMIN_USER} /home/${DOCKER_ADMIN_USER}/.ssh/

# assign
chown -R ${DOCKER_ADMIN_USER}:docker /var/lib/docker-data/


################################################################
#
#    user site software
#
################################################################

# install pip for python
su - ${DOCKER_ADMIN_USER} << EOF
cd ~
curl -O https://bootstrap.pypa.io/get-pip.py
python get-pip.py --user
rm -f get-pip.py
PATH=~/.local/bin:$PATH
pip install awscli --upgrade --user
EOF

exit 0