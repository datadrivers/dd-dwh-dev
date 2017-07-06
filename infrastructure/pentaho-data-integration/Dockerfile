FROM java:8-jre

MAINTAINER dd-lkr

# Set required environment vars
ENV PDI_RELEASE=7.1 \
    PDI_VERSION=7.1.0.0-12 \
    PENTAHO_JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64 \
    USER_HOME=/home/pentaho

	
RUN mkdir $USER_HOME \
        $USER_HOME/.kettle \
        $USER_HOME/repository \
    && wget --progress=bar:force http://downloads.sourceforge.net/project/pentaho/Data%20Integration/${PDI_RELEASE}/pdi-ce-${PDI_VERSION}.zip -O /tmp/pdi-ce-${PDI_VERSION}.zip \
    && unzip -q /tmp/pdi-ce-${PDI_VERSION}.zip -d  $USER_HOME \
    && rm -f /tmp/pdi-ce-${PDI_VERSION}.zip \
    && chmod +x $USER_HOME/data-integration/*.sh \
    && groupadd -r pentaho \
    && useradd -s /bin/bash -d ${USER_HOME} -r -g pentaho pentaho

COPY ./repositories.xml ${USER_HOME}/.kettle/
COPY kettle.properties ${USER_HOME}/.kettle/
COPY drivers/ ${USER_HOME}/data-integration/lib/
COPY repository/ ${USER_HOME}/repository/

RUN chown -R pentaho:pentaho ${USER_HOME}

USER pentaho

ENV PATH=${USER_HOME}/data-integration:$PATH

WORKDIR ${USER_HOME}/data-integration
