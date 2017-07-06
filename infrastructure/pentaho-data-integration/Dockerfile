FROM java:8-jre

MAINTAINER dd-lkr

# Set required environment vars
ENV PDI_RELEASE=7.1 \
    PDI_VERSION=7.1.0.0-12 \
    PENTAHO_JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64 \
    PENTAHO_HOME=/home/pentaho

# Create user and directories
RUN mkdir \
    $PENTAHO_HOME/ \
    $PENTAHO_HOME/scripts \
    $PENTAHO_HOME/data-integration/ \
    $PENTAHO_HOME/data-integration/.kettle \
    $PENTAHO_HOME/data-integration/repositories && \
    groupadd -r pentaho && \
    useradd -s /bin/bash -d ${PENTAHO_HOME} -r -g pentaho pentaho && \
    chown pentaho:pentaho ${PENTAHO_HOME}

# COPY repo-config/repositories.xml $PENTAHO_HOME/data-integration/.kettle/
# COPY test/ $PENTAHO_HOME/data-integration/repositories/test/
# COPY drivers/ $PENTAHO_HOME/data-integration/lib/

COPY /scripts $PENTAHO_HOME/scripts/

RUN chown -R pentaho:pentaho $PENTAHO_HOME

USER pentaho

# Download PDI
RUN /usr/bin/wget \
    --progress=dot:giga \
    http://downloads.sourceforge.net/project/pentaho/Data%20Integration/${PDI_RELEASE}/pdi-ce-${PDI_VERSION}.zip \
    -O /tmp/pdi-ce-${PDI_VERSION}.zip && \
    /usr/bin/unzip -q /tmp/pdi-ce-${PDI_VERSION}.zip -d  $PENTAHO_HOME && \
    rm /tmp/pdi-ce-${PDI_VERSION}.zip

ENV KETTLE_HOME=$PENTAHO_HOME/data-integration \
    PATH=$KETTLE_HOME:$PATH

WORKDIR $KETTLE_HOME

ENTRYPOINT ["../scripts/docker-entrypoint.sh"]
