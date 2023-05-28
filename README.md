# Docker Project

This Docker project provides a containerized environment with Elasticsearch, Kibana, Node.js, Redis, and RabbitMQ. It also includes the Hyperion application for historical data indexing.

## Technical Specification

### Components

- Elasticsearch 8.x: Powerful search and analytics engine
- Kibana: Web interface for Elasticsearch data visualization and management
- Node.js 18.x: JavaScript runtime for running Node.js applications
- Redis: In-memory data structure store
- RabbitMQ: Message broker and queue manager

### Elasticsearch Configuration

- Custom Elasticsearch configuration settings applied:
  - Data and log paths
  - Cluster settings
  - JVM optionson
  - SSL disabled

  ```dockerfile
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
  && sysctl -w vm.max_map_count=262144
  ```
  * `sed -i 's|path.data: /var/lib/elasticsearch|path.data: /data/es-data|g' /etc/elasticsearch/elasticsearch.yml`: Modifies the `path.data` setting in `elasticsearch.yml` to change the Elasticsearch data directory to `/data/es-data`.
  * `sed -i 's|path.logs: /var/log/elasticsearch|path.logs: /data/es-logs|g' /etc/elasticsearch/elasticsearch.yml`: Modifies the `path.logs` setting in `elasticsearch.yml` to change the Elasticsearch logs directory to /`data/es-logs`.
  * `sed -i 's/cluster.initial_master_nodes:.*/cluster.initial_master_nodes: ["es1"]/g' /etc/elasticsearch/elasticsearch.yml`: Sets the `cluster.initial_master_nodes` setting to `["es1"]` in `elasticsearch.yml` to define the initial master node(s) for Elasticsearch.
  * `echo 'discovery.seed_hosts: ["127.0.0.1"]' >> /etc/elasticsearch/elasticsearch.yml`: Appends the `discovery.seed_hosts` setting with the value ["127.0.0.1"] to the `elasticsearch.yml` file to specify the seed hosts for Elasticsearch discovery.
  * `echo 'node.name: es1' >> /etc/elasticsearch/elasticsearch.yml`: Appends the `node.name` setting with the value `es1` to the `elasticsearch.yml` file to specify the name of the Elasticsearch node.
  * `echo "-Xms31g" >> /etc/elasticsearch/jvm.options`: Appends the minimum heap size (`-Xms`) setting with the value `31g` to the `jvm.options` file for Elasticsearch.
  * `echo "-Xmx31g" >> /etc/elasticsearch/jvm.options`: Appends the maximum heap size (`-Xmx`) setting with the value `31g` to the `jvm.options` file for Elasticsearch.
  * `sed -i '/^xpack.security.http.ssl:/,/^[^ ]/ s/^ enabled: .*/ enabled: false/' /etc/elasticsearch/elasticsearch.yml`: Disables SSL by modifying the `xpack.security.http.ssl.enabled` setting to `false` in the `elasticsearch.yml` file.
  * `systemctl daemon-reload && systemctl enable elasticsearch.service`: Performs a system daemon reload and enables the Elasticsearch service.
  * `mkdir /var/run/elasticsearch && mkdir /data && chown -R elasticsearch:elasticsearch /var/run/elasticsearch && chown -R elasticsearch:elasticsearch /data`: Creates the `/var/run/elasticsearch` directory and the `/data` directory, and changes their ownership to the `elasticsearch` user and group.
  * `sysctl -w vm.max_map_count=262144`: Configures the `vm.max_map_count` kernel parameter to increase the maximum number of memory map areas for Elasticsearch.

- Bootstrap password for Elasticsearch is set using the `ELASTIC_PASSWORD` argument.

### Kibana Configuration

- Elasticsearch authentication and server host configuration added to `kibana.yml`.

### Redis Configuration

- `supervised` directive in the Redis configuration file changed to `systemd`.
- The following lines of code are used to dynamically configure the maximum memory allowed for Redis:

  ```dockerfile
  RUN total_memory=$(free -m | awk '/^Mem:/{print $2}') \
      && max_memory=$(expr $total_memory / 4)M \
      && sed -i "s/^# maxmemory .*/maxmemory $max_memory/" /etc/redis/redis.conf
  ```
  * `total_memory=$(free -m | awk '/^Mem:/{print $2}')`: Executes the free command to retrieve the total memory available on the host system, and uses awk to extract the value
  * `max_memory=$(expr $total_memory / 4)M`: Calculates 25% of the total memory and appends "M" to specify the value in megabytes.
  * `sed -i "s/^# maxmemory .*/maxmemory $max_memory/" /etc/redis/redis.conf`: Updates the Redis configuration file (`/etc/redis/redis.conf`) to set the `maxmemory` directive with the calculated value. This removes any existing comment (`#`) from the line and replaces it with the new value.
  
### RabbitMQ Configuration

- Default user, password, and vhost settings defined in the `rabbitmq.conf` file. Please see arguments passed for the username and password in the Dockerfile

### Hyperion Application

- The Hyperion application is installed and set up within the Docker image.
- To access the Hyperion application, navigate to the `/apps/installs/hyperion-history-api` directory.

### Health Checks

- Health checks are implemented for the following components:
  - Elasticsearch: Checks cluster health by making a request to `localhost:9200/_cluster/health`.
  - Kibana: Checks Kibana server status by making a request to `localhost:5601/api/status`.
  - RabbitMQ: Verifies RabbitMQ node health using `rabbitmqctl node_health_check`.
  - Redis: Tests Redis server availability using `redis-cli ping`.

## Usage

To use this Docker image, follow these steps:

1. Configure any necessary Arguments in the Dockerfile.
2. Build the image
3. Run the Docker container using the appropriate command or Docker Compose (look at examples below)
4. Provide the necessary connections.json in your hyperion root app and wax.config.json in your chain config for your API and Indexer
5. As part of the build, a start and stop script will be created
  - /apps/startup.sh to start up all applications
  - /apps/stop.sh to shutdown all applications
6. When the connections and chain config for WAX, you can register and run wax-indexer and wax-api from your Hyperion App
```bash
# Start WAX indexer
./run wax-indexer

# Start WAX API
./run wax-api
```
  - You can verify the services are registered and running by executing `pm2 list`
  
  | id | name          | namespace | version  | mode    | pid | uptime | ↺   | status  | cpu   | mem     | user  | watching |
  |----|---------------|-----------|----------|---------|-----|--------|-----|---------|-------|---------|-------|----------|
  | 1  | wax-api       | wax       | 3.3.9-6  | cluster | 1129| 44h    | 0   | online  | 0%    | 93.1mb  | root  | disabled |
  | 0  | wax-indexer   | wax       | 3.3.9-6  | fork    | 890 | 44h    | 0   | online  | 0%    | 106.4mb | root  | disabled |


7. Access the services: (*Please Note you can make this accessible by proxy externally* [documenation](http://wiki.oiac.io/haproxy/))
   - Elasticsearch: Access Elasticsearch at `http://localhost:9200`.
   - Kibana: Access Kibana at `http://localhost:5601`.
   - Hyperion: Navigate to the Hyperion application within the container.
   - RabbitMQ and Redis: These services are accessible within the container.

For detailed instructions on building, running, and configuring the Docker container, please refer to the [documentation](http://wiki.oiac.io/containers/).

## Examples

Here are some examples of how you can use this Docker image:

```bash
# Pull the Docker image from the registry
docker pull your-image:tag

# Build the Docker image
docker build -t your-image:tag -f ./your-dockerfile

# Run the Docker container using default storage
docker run -d --name your-container --publish 7000:7000 --publish 5601:5601 --publish 15672:15672 --publish 1234:1234 --tty your-image:tag

# Run the Docker container using mapped docker volumes (i.e. additional disk type to store large data sets)
docker run -d --name your-container --publish 7000:7000 --publish 5601:5601 --publish 15672:15672 --publish 1234:1234 --mount source=hyperiontestnet,target=/data --tty your-image:tag

# Run the Docker container using mapped docker volumes (i.e. additional disk type to store large data sets) and on restricted to loopback interface
docker run -d --name your-container --publish 127.0.0.1:7000:7000 --publish 127.0.0.1:5601:5601 --publish 127.0.0.1:15672:15672 --publish 127.0.0.1:1234:1234 --mount source=hyperiontestnet,target=/data --tty your-image:tag

