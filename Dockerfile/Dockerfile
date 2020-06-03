################################################################################
# Build stage 0.1 `elasticsearch-builder`:
# Extract elasticsearch artifact
# Install required plugins
# Set gid=0 and make group perms==owner perms
################################################################################
FROM centos:7 AS elasticsearch-builder

    ENV PATH /usr/share/elasticsearch/bin:$PATH

    RUN \
        groupadd -g 1000 elasticsearch \
        && adduser -u 1000 -g 1000 -d /usr/share/elasticsearch elasticsearch

    WORKDIR /usr/share/elasticsearch

    ARG elasticsearch_version=7.7.0
    RUN \
        cd /opt \
        && curl --retry 8 -s -L -O https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-${elasticsearch_version}-linux-x86_64.tar.gz \
        && cd -

    ARG elasticsearch_version=7.7.0
    RUN \
        tar zxf /opt/elasticsearch-${elasticsearch_version}-linux-x86_64.tar.gz --strip-components=1 \
        \
        && grep ES_DISTRIBUTION_TYPE=tar /usr/share/elasticsearch/bin/elasticsearch-env \
        && sed -ie 's/ES_DISTRIBUTION_TYPE=tar/ES_DISTRIBUTION_TYPE=docker/' /usr/share/elasticsearch/bin/elasticsearch-env \
        \
        && mkdir -p config data logs \
        && chmod 0775 config data logs

    COPY elasticsearch/config/elasticsearch.yml elasticsearch/config/log4j2.properties config/

    # Ensure that group permissions are the same as user permissions.
    # This will help when relying on GID-0 to run Kibana, rather than UID-1000.
    # OpenShift does this, for example.
    # REF: https://docs.openshift.org/latest/creating_images/guidelines.html
    RUN \
        chmod -R g=u /usr/share/elasticsearch \
        && find /usr/share/elasticsearch -type d -exec chmod g+s {} \;

################################################################################
# Build stage 0.2 `kibana-builder`:
# Extract Kibana and make various file manipulations.
################################################################################
FROM centos:7 AS kibana-builder

    ENV PATH /usr/share/kibana/bin:$PATH

    RUN \
        groupadd -g 1001 kibana \
        && adduser -u 1001 -g 1001 -d /usr/share/kibana kibana

    WORKDIR /usr/share/kibana

    ARG kibana_version=7.7.0
    RUN \
        cd /opt \
        && curl --retry 8 -s -L -O https://artifacts.elastic.co/downloads/kibana/kibana-${kibana_version}-linux-x86_64.tar.gz \
        && cd -
        
    ARG kibana_version=7.7.0
    RUN \
        tar zxf /opt/kibana-${kibana_version}-linux-x86_64.tar.gz --strip-components=1

    COPY kibana/config/kibana.yml config/

    # Ensure that group permissions are the same as user permissions.
    # This will help when relying on GID-0 to run Kibana, rather than UID-1001.
    # OpenShift does this, for example.
    # REF: https://docs.openshift.org/latest/creating_images/guidelines.html
    RUN \
        chmod -R g=u /usr/share/kibana \
        && find /usr/share/kibana -type d -exec chmod g+s {} \;

################################################################################
# Build stage 0.3 `logstash-builder`:
# Extract Logstash and make various file manipulations.
################################################################################
FROM centos:7 AS logstash-builder

    ENV PATH=/usr/share/logstash/bin:$PATH

    RUN \
        groupadd -g 1002 logstash \
        && adduser -u 1002 -g 1002 -d /usr/share/logstash logstash

    WORKDIR /usr/share/logstash

    ARG logstash_version=7.7.0
    RUN \
        cd /opt \
        && curl --retry 8 -s -L -O https://artifacts.elastic.co/downloads/logstash/logstash-${logstash_version}.tar.gz \
        && cd -

    ARG logstash_version=7.7.0
    RUN \
        tar zxf /opt/logstash-${logstash_version}.tar.gz --strip-components=1
    
    COPY logstash/config/pipelines.yml logstash/config/logstash.yml logstash/config/log4j2.properties config/
    COPY logstash/pipeline/default.conf pipeline/logstash.conf

    # Ensure that group permissions are the same as user permissions.
    # This will help when relying on GID-0 to run Logstash, rather than UID-1001.
    # OpenShift does this, for example.
    # REF: https://docs.openshift.org/latest/creating_images/guidelines.html
    RUN \
        chmod -R g=u /usr/share/logstash \
        && find /usr/share/logstash -type d -exec chmod g+s {} \;

################################################################################
# Build stage 1 `elasticsearch`:
# Copy elasticsearch from stage 0.1
################################################################################
FROM centos:7 AS elasticsearch

    ENV ELASTIC_CONTAINER true

    RUN \
        for iter in {1..10}; do yum update -y \
        && yum install -y \
            nc \
        && yum clean all && exit_code=0 && break || exit_code=$? && echo "yum error: retry $iter in 10s" && sleep 10; done; \
        (exit $exit_code)

    RUN \
        groupadd -g 1000 elasticsearch \
        && adduser -u 1000 -g 1000 -G 0 -d /usr/share/elasticsearch elasticsearch \
        && chmod 0775 /usr/share/elasticsearch \
        && chgrp 0 /usr/share/elasticsearch

    COPY --from=elasticsearch-builder --chown=1000:0 /usr/share/elasticsearch /usr/share/elasticsearch

    # Replace OpenJDK's built-in CA certificate keystore with the one from the OS
    # vendor. The latter is superior in several ways.
    # REF: https://github.com/elastic/elasticsearch-docker/issues/171
    RUN \
        ln -sf /etc/pki/ca-trust/extracted/java/cacerts /usr/share/elasticsearch/jdk/lib/security/cacerts

    ENV PATH /usr/share/elasticsearch/bin:$PATH

    COPY --chown=1000:0 elasticsearch/bin/docker-entrypoint.sh /usr/local/bin/elasticsearch-docker.sh

    # Openshift overrides USER and uses ones with randomly uid>1024 and gid=0
    # Allow ENTRYPOINT (and ES) to run even with a different user
    RUN \
        chmod g+ws /usr/share/elasticsearch \
        && find /usr/share/elasticsearch -gid 0 -and -not -perm /g+w -exec chmod g+w {} \; \
        && chgrp 0 /usr/local/bin/elasticsearch-docker.sh \
        && chmod 0775 /usr/local/bin/elasticsearch-docker.sh

    EXPOSE 9200 9300

################################################################################
# Build stage 2 `kibana`:
# Overloads stage 1 (elasticsearch)
# Copy kibana from stage 0.2
################################################################################
FROM elasticsearch AS kibana

    RUN \
        for iter in {1..10}; do yum update -y \
        && yum install -y \
            fontconfig \
            freetype \
        && yum clean all && exit_code=0 && break || exit_code=$? && echo "yum error: retry $iter in 10s" && sleep 10; done; \
        (exit $exit_code)

    RUN \
        groupadd -g 1001 kibana \
        && adduser -u 1001 -g 1001 -G 0 -d /usr/share/kibana kibana \
        && chmod 0775 /usr/share/kibana \
        && chgrp 0 /usr/share/kibana

    COPY --from=kibana-builder --chown=1001:0 /usr/share/kibana /usr/share/kibana

    ENV PATH /usr/share/kibana/bin:$PATH

    COPY --chown=1001:0 kibana/bin/kibana-docker.sh /usr/local/bin/kibana-docker.sh

    # Openshift overrides USER and uses ones with randomly uid>1024 and gid=0
    # Allow ENTRYPOINT (and ES) to run even with a different user
    RUN \
        chmod g+ws /usr/share/kibana \
        && find /usr/share/kibana -gid 0 -and -not -perm /g+w -exec chmod g+w {} \; \
        && chgrp 0 /usr/local/bin/kibana-docker.sh \
        && chmod 0775 /usr/local/bin/kibana-docker.sh

    EXPOSE 5601

################################################################################
# Build stage 3 `logstash`:
# Overloads stage 2 (kibana)
# Copy kibana from stage 0.2
################################################################################
FROM kibana AS logstash

    ENV ELASTIC_CONTAINER true
    ENV LANG='en_US.UTF-8' LC_ALL='en_US.UTF-8'

    RUN \
        for iter in {1..10}; do yum update -y \
        && yum install -y \
            java-11-openjdk-devel \
            which \
        && yum clean all && exit_code=0 && break || exit_code=$? && echo "yum error: retry $iter in 10s" && sleep 10; done; \
        (exit $exit_code)
    
    RUN \
        groupadd -g 1002 logstash \
        && adduser -u 1002 -g 1002 -G 0 -d /usr/share/logstash logstash \
        && chmod 0775 /usr/share/logstash \
        && chgrp 0 /usr/share/logstash
    
    COPY --from=logstash-builder --chown=1002:0 /usr/share/logstash /usr/share/logstash

    ENV PATH /usr/share/logstash/bin:$PATH

    COPY --chown=1002:0 logstash/env2yaml/env2yaml /usr/local/bin/env2yaml
    COPY --chown=1002:0 logstash/bin/docker-entrypoint.sh /usr/local/bin/logstash-docker.sh

    # Openshift overrides USER and uses ones with randomly uid>1024 and gid=0
    # Allow ENTRYPOINT (and ES) to run even with a different user
    RUN \
        chmod g+ws /usr/share/logstash \
        && find /usr/share/logstash -gid 0 -and -not -perm /g+w -exec chmod g+w {} \; \
        && chgrp 0 /usr/local/bin/env2yaml \
        && chmod 0775 /usr/local/bin/env2yaml \
        && chgrp 0 /usr/local/bin/logstash-docker.sh \
        && chmod 0775 /usr/local/bin/logstash-docker.sh
    
    EXPOSE 9600 5044

################################################################################
# Build stage 4 `entrypoint`:
# Overloads stage 3 (logstash)
# Add entrypoint
################################################################################
FROM logstash AS entrypoint

    COPY --chown=1000:0 docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh

    # Openshift overrides USER and uses ones with randomly uid>1024 and gid=0
    # Allow ENTRYPOINT (and ES) to run even with a different user
    RUN \
        chmod g=u /etc/passwd \
        && chgrp 0 /usr/local/bin/docker-entrypoint.sh \
        && chmod 0775 /usr/local/bin/docker-entrypoint.sh

    ARG elasticsearch_version=7.7.0
    LABEL \
        org.label-schema.schema-version="1.0" \
        org.label-schema.vendor="Elastic" \
        org.label-schema.name="elasticsearch" \
        org.label-schema.version="${elasticsearch_version}" \
        org.label-schema.url="https://www.elastic.co/products/elasticsearch" \
        org.label-schema.vcs-url="https://github.com/elastic/elasticsearch" \
        license="Elastic License"

    ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
    # Dummy overridable parameter parsed by entrypoint
    CMD ["eswrapper"]
