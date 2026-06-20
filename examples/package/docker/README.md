# Docker Package Manager Example

This example demonstrates Docker package management and container orchestration using the Docker package manager.

## Prerequisites

- Linux system with Docker support
- sudo privileges
- Internet connection for Docker image downloads

## Running the Example

```bash
# Run the Docker package configuration
dart run ../../../bin/main.dart apply -c config
```

## What This Example Demonstrates

### 1. Docker Installation (`docker-install`)
- Installs Docker and related tools: docker.io, docker-compose, docker-doc
- Starts and enables Docker service
- Uses Docker package manager specifically
- Includes before/after hooks for setup verification

### 2. Docker User Setup (`docker-user-setup`)
- Adds current user to docker group
- Enables running Docker commands without sudo
- Provides warning about logout requirement

### 3. Docker Compose Setup (`docker-compose-setup`)
- Creates docker-compose.yml configuration
- Starts Docker Compose services
- Demonstrates multi-container orchestration

### 4. Docker Image Management (`docker-images`)
- Pulls common Docker images: nginx:alpine, redis:alpine, postgres:13
- Lists available Docker images
- Demonstrates image management

### 5. Docker Container Management (`docker-containers`)
- Runs test containers: nginx and redis
- Exposes ports for testing
- Lists running containers

### 6. Docker Cleanup (`docker-cleanup`)
- Stops and removes test containers
- Performs system cleanup
- Demonstrates resource management

## Docker-Specific Features

### Service Management
```configr
after {
  execute {
    command "systemctl start docker"
    on_success true
  }
}
```

### User Group Management
```configr
execute {
  command "sudo usermod -aG docker $USER"
  on_success true
}
```

### Container Orchestration
- Docker Compose integration
- Multi-container setups
- Volume and network management

## Testing Different Scenarios

### Test Docker Installation
1. Run the configuration and observe Docker installation
2. Verify Docker service is running

### Test Container Management
1. Run containers and verify they're accessible
2. Test port forwarding and service connectivity

### Test Docker Compose
1. Use the provided docker-compose.yml
2. Verify multi-container orchestration

### Test Cleanup
1. Run cleanup operations
2. Verify resources are properly removed

## Expected Results

After running the configuration:
- Docker installed and running
- User added to docker group
- Docker images pulled
- Test containers running
- Docker Compose services started
- Cleanup operations completed

## Services and Ports

The example sets up the following services:

- **Nginx**: http://localhost:8080
- **Redis**: localhost:6379
- **PostgreSQL**: localhost:5432

## Cleanup

To clean up Docker resources:

```bash
# Stop and remove containers
docker stop test-nginx test-redis
docker rm test-nginx test-redis

# Stop Docker Compose services
docker-compose down

# Remove images
docker rmi nginx:alpine redis:alpine postgres:13

# Clean up system
docker system prune -f

# Remove volumes
docker volume prune -f
```

## Docker-Specific Notes

- Requires sudo privileges for installation
- Docker service must be running for container operations
- User must be in docker group to run containers without sudo
- Docker Compose requires docker-compose.yml file
- Use `docker ps` to list running containers
- Use `docker images` to list available images
- Use `docker logs <container>` to view container logs
- Consider using `--no-confirm` for automated installations

## Security Considerations

- Docker containers run with elevated privileges
- Exposed ports should be secured in production
- Use Docker secrets for sensitive data
- Regularly update Docker images for security patches
- Consider using Docker Content Trust for image verification
