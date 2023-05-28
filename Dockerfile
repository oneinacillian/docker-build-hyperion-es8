FROM ubuntu:20.04
WORKDIR /apps
ARG DEBIAN_FRONTEND=noninteractive
ARG ELASTIC_PASSWORD=123456
ARG ELASTIC_KESTORE_PASSWORD=123456
ARG RABBITMQ_USER=hyper
ARG RABBITMQ_PASS=123456
RUN apt-get update \
&& apt-get -y upgrade \
&& apt -y install npm git wget curl gnupg gnupg2 gnupg1 vim htop systemctl aptitude git lxc-utils netfilter-persistent sysstat ntp gpg

RUN wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | apt-key add - \
&& apt-get install apt-transport-https \
&& echo "deb https://artifacts.elastic.co/packages/8.x/apt stable main" | tee /etc/apt/sources.list.d/elastic-8.x.list \
&& apt-get update \ 
&& apt-get install -y elasticsearch

# Set the Elasticsearch bootstrap password
RUN echo "bootstrap.password: ${ELASTIC_PASSWORD}" >> /etc/elasticsearch/elasticsearch.yml

# Set the Elasticsearch keystore password
RUN echo "${ELASTIC_KESTORE_PASSWORD}" | /usr/share/elasticsearch/bin/elasticsearch-keystore add --stdin --force "bootstrap.password"
RUN sed -i 's|path.data: /var/lib/elasticsearch|path.data: /data/es-data|g' /etc/elasticsearch/elasticsearch.yml \
&& sed -i 's|path.logs: /var/log/elasticsearch|path.logs: /data/es-logs|g' /etc/elasticsearch/elasticsearch.yml \
&& sed -i 's/cluster.initial_master_nodes:.*/cluster.initial_master_nodes: ["es1"]/g' /etc/elasticsearch/elasticsearch.yml \
&& echo 'discovery.seed_hosts: ["127.0.0.1"]' >> /etc/elasticsearch/elasticsearch.yml \
&& echo 'node.name: es1' >> /etc/elasticsearch/elasticsearch.yml \
&& echo "-Xms31g" >> /etc/elasticsearch/jvm.options \
&& echo "-Xmx31g" >> /etc/elasticsearch/jvm.options \
&& sed -i '/^xpack.security.http.ssl:/,/^[^ ]/ s/^  enabled: .*/  enabled: false/' /etc/elasticsearch/elasticsearch.yml \
&& systemctl daemon-reload && systemctl enable elasticsearch.service \
&& mkdir /var/run/elasticsearch && mkdir /data && chown -R elasticsearch:elasticsearch /var/run/elasticsearch && chown -R elasticsearch:elasticsearch /data \
&& sysctl -w vm.max_map_count=262144 \
&& systemctl start elasticsearch


# Configure Kibana for authentication
RUN apt-get install kibana
RUN systemctl start elasticsearch && yes | /usr/share/elasticsearch/bin/elasticsearch-reset-password -u kibana_system >> /tmp/test.file
RUN PASSWORD=$(cat /tmp/test.file | grep -oP 'New value: \K.*' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//') \
&& echo "elasticsearch.password: \"$PASSWORD\"" >> /etc/kibana/kibana.yml \
&& echo 'elasticsearch.username: "kibana_system"' >> /etc/kibana/kibana.yml \
&& echo 'server.host: "0.0.0.0"' >> /etc/kibana/kibana.yml

# Install Node.js 16.x
RUN curl -fsSL https://deb.nodesource.com/setup_16.x | bash - && \
    apt-get -y install nodejs && \
    rm -rf /var/lib/apt/lists/*


# Install redis
RUN apt-get update && \
    apt-get -y upgrade && \
    apt-get -y install redis-server && \
    rm -rf /var/lib/apt/lists/*

# Replace supervised auto with supervised systemd
RUN sed -i 's/^supervised auto$/supervised systemd/g' /etc/redis/redis.conf

# Add supervised systemd if it does not exist
RUN echo -e "\n# Set supervised systemd if not already set\nif [ ! -z \"\$(grep -E '^supervised' /etc/redis/redis.conf | grep -E -v '^(#|;|//)')\" ]; then\n  echo 'supervised is already set in /etc/redis/redis.conf';\nelse\n  echo 'supervised systemd' >> /etc/redis/redis.conf;\nfi" >> /usr/local/bin/start-redis.sh && \
    chmod +x /usr/local/bin/start-redis.sh

# Configure Redis performance parameters
RUN total_memory=$(free -m | awk '/^Mem:/{print $2}') \
    && max_memory=$(expr $total_memory / 4)M \
    && sed -i "s/^# maxmemory .*/maxmemory $max_memory/" /etc/redis/redis.conf

# Add RabbitMQ signing key and repository
RUN curl -1sLf "https://keys.openpgp.org/vks/v1/by-fingerprint/0A9AF2115F4687BD29803A206B73A36E6026DFCA" | gpg --dearmor | tee /usr/share/keyrings/com.rabbitmq.team.gpg > /dev/null \
&& curl -1sLf "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0xf77f1eda57ebb1cc" | gpg --dearmor | tee /usr/share/keyrings/net.launchpad.ppa.rabbitmq.erlang.gpg > /dev/null \
&& curl -1sLf "https://packagecloud.io/rabbitmq/rabbitmq-server/gpgkey" | gpg --dearmor | tee /usr/share/keyrings/io.packagecloud.rabbitmq.gpg > /dev/null \
&& echo "deb [signed-by=/usr/share/keyrings/net.launchpad.ppa.rabbitmq.erlang.gpg] http://ppa.launchpad.net/rabbitmq/rabbitmq-erlang/ubuntu bionic main" >> /etc/apt/sources.list.d/rabbitmq.list \
&& echo "deb-src [signed-by=/usr/share/keyrings/net.launchpad.ppa.rabbitmq.erlang.gpg] http://ppa.launchpad.net/rabbitmq/rabbitmq-erlang/ubuntu bionic main" >> /etc/apt/sources.list.d/rabbitmq.list \
&& echo "deb [signed-by=/usr/share/keyrings/io.packagecloud.rabbitmq.gpg] https://packagecloud.io/rabbitmq/rabbitmq-server/ubuntu/ bionic main" >> /etc/apt/sources.list.d/rabbitmq.list \
&& echo "deb-src [signed-by=/usr/share/keyrings/io.packagecloud.rabbitmq.gpg] https://packagecloud.io/rabbitmq/rabbitmq-server/ubuntu/ bionic main" >> /etc/apt/sources.list.d/rabbitmq.list

# Install RabbitMQ server
RUN apt-get update && \
    apt-get install -y erlang-base erlang-asn1 erlang-crypto erlang-eldap erlang-ftp erlang-inets erlang-mnesia erlang-os-mon erlang-parsetools erlang-public-key erlang-runtime-tools erlang-snmp erlang-ssl erlang-syntax-tools erlang-tftp erlang-tools erlang-xmerl && \
    apt-get install rabbitmq-server -y --fix-missing && \
    rabbitmq-plugins enable rabbitmq_management && \
    chown -R rabbitmq:rabbitmq /var/lib/rabbitmq

# Configure RabbitMQ server
RUN touch /etc/rabbitmq/rabbitmq.conf \ 
&& echo "default_user = $RABBITMQ_USER" >> /etc/rabbitmq/rabbitmq.conf  \
&& echo "default_pass = $RABBITMQ_PASS" >> /etc/rabbitmq/rabbitmq.conf \
&& echo "default_vhost = hyperion" >> /etc/rabbitmq/rabbitmq.conf \
&& systemctl start rabbitmq-server

# Configure startup and shutdown scripts
RUN echo '#!/bin/bash' >> /apps/startup.sh \ 
&& echo "systemctl start elasticsearch" >> /apps/startup.sh \
&& echo "systemctl start kibana" >> /apps/startup.sh \
&& echo "systemctl start rabbitmq-server" >> /apps/startup.sh \
&& echo "systemctl start redis-server" >> /apps/startup.sh \
&& echo "tail -f /dev/null" >> /apps/startup.sh \
&& echo "systemctl stop  elasticsearch" >> /apps/stop.sh \
&& echo "systemctl stop kibana" >> /apps/stop.sh \
&& echo "systemctl stop rabbitmq-server" >> /apps/stop.sh \
&& echo "systemctl stop redis-server" >> /apps/stop.sh \
&& chmod +x /apps/startup.sh \
&& chmod +x /apps/stop.sh

# Install pm2
RUN npm install pm2@latest -g

# Download Hyperion
RUN mkdir -p /apps/installs && cd /apps/installs && \
git clone https://github.com/eosrio/hyperion-history-api.git --branch main && \
cd /apps/installs/hyperion-history-api && npm install


# Elasticsearch health check
HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
  CMD curl --silent --fail localhost:9200/_cluster/health || exit 1

# Kibana health check
HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
  CMD curl --silent --fail localhost:5601/api/status || exit 1

# RabbitMQ health check
HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
  CMD rabbitmqctl node_health_check || exit 1

# Redis health check
HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
  CMD redis-cli ping || exit 1

ENTRYPOINT ["/apps/startup.sh"]