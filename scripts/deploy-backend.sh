#!/bin/bash
set -e

ENV=$1
IMAGE_TAG=$2  
VM_HOST=$3

if [ "$#" -ne 3 ]; then
    echo "Usage: $0 <environment> <image_tag> <vm_host>"
    exit 1
fi

echo "Deploying backend to $ENV environment"
echo "Image: dreamscape/backend:$IMAGE_TAG"
echo "VM: $VM_HOST"

ssh -o StrictHostKeyChecking=no ubuntu@$VM_HOST "
  echo 'Stopping existing backend container...'
  docker stop dreamscape-backend-$ENV 2>/dev/null || echo 'No existing container'
  docker rm dreamscape-backend-$ENV 2>/dev/null || echo 'No container to remove'
  
  echo 'Pulling new backend image...'
  docker pull dreamscape/backend:$IMAGE_TAG
  
  echo 'Starting new backend container...'
  docker run -d \
    --name dreamscape-backend-$ENV \
    --restart unless-stopped \
    -p 8080:8080 \
    -e NODE_ENV=$ENV \
    dreamscape/backend:$IMAGE_TAG
  
  echo 'Checking backend health...'
  sleep 15
  
  if ! docker ps | grep dreamscape-backend-$ENV; then
    echo 'Backend container is not running'
    exit 1
  fi
  
  for i in {1..10}; do
    if curl -f -s http://localhost:8080/health > /dev/null 2>&1 || curl -f -s http://localhost:8080/ > /dev/null 2>&1; then
      echo 'Backend is healthy'
      exit 0
    else
      echo \"Attempt \$i/10: Backend not responding, waiting...\"
      sleep 5
    fi
  done
  
  echo 'Backend health check failed'
  exit 1
"

echo "Backend deployment completed!"