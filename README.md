# Docker Project

This Docker project provides a containerized environment with Elasticsearch, Kibana, Node.js, Redis, and RabbitMQ. It also includes the Hyperion application for historical data indexing.

## Technical Specification

### Components

- Elasticsearch 8.x: Powerful search and analytics engine
- Kibana: Web interface for Elasticsearch data visualization and management
- Node.js 16.x: JavaScript runtime for running Node.js applications
- Redis: In-memory data structure store
- RabbitMQ: Message broker and queue manager

### Elasticsearch Configuration

- Custom Elasticsearch configuration settings applied:
  - Data and log paths
    * Elasticsearch data path will be set as /data/es-data
    * Elasticseach log path will be set as /data/es-logs
  - Cluster settings
  - JVM options
    * 31G static configuration
  - SSL disabled
- Bootstrap password for Elasticsearch is set using the `ELASTIC_PASSWORD` argument.

### Kibana Configuration

- Elasticsearch authentication and server host configuration added to `kibana.yml`.

### Redis Configuration

- `supervised` directive in the Redis configuration file changed to `systemd`.

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
5. When the connections and chain config for WAX, you can register and run wax-indexer and wax-api from your Hyperion App
```bash
# Start WAX indexer
./run wax-indexer

# Start WAX API
./run wax-api
```
6. Access the services:
   - Elasticsearch: Access Elasticsearch at `http://localhost:9200`.
   - Kibana: Access Kibana at `http://localhost:5601`.
   - Hyperion: Navigate to the Hyperion application within the container.
   - RabbitMQ and Redis: These services are accessible within the container.

For detailed instructions on building, running, and configuring the Docker container, please refer to the [documentation](docs/).

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

