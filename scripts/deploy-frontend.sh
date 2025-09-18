#!/bin/bash
set -e

ENV=$1
IMAGE_TAG=$2
VM_HOST=$3
SSH_KEY_FILE=$4

if [ "$#" -ne 4 ]; then
    echo "Usage: $0 <environment> <image_tag> <vm_host> <ssh_key_file>"
    exit 1
fi

echo "🚀 Deploying frontend to $ENV"
echo "Image: dreamscape/frontend:$IMAGE_TAG"
echo "VM: $VM_HOST"
echo "Key: $SSH_KEY_FILE"

ssh -i "$SSH_KEY_FILE" -o StrictHostKeyChecking=no ubuntu@$VM_HOST "
  echo 'Stopping existing frontend container...'
  docker stop dreamscape-frontend-$ENV 2>/dev/null || echo 'No existing container'
  docker rm dreamscape-frontend-$ENV 2>/dev/null || echo 'No container to remove'
  
  echo 'Pulling new frontend image...'
  docker pull dreamscape/frontend:$IMAGE_TAG
  
  echo 'Starting new frontend container...'
  docker run -d \
    --name dreamscape-frontend-$ENV \
    --restart unless-stopped \
    -p 80:80 \
    -e NODE_ENV=$ENV \
    dreamscape/frontend:$IMAGE_TAG
  
  echo 'Checking frontend health...'
  sleep 15
  
  if ! docker ps | grep dreamscape-frontend-$ENV; then
    echo '❌ Frontend container is not running'
    exit 1
  fi
  
  for i in {1..10}; do
    if curl -f -s http://localhost/ > /dev/null 2>&1; then
      echo '✅ Frontend is healthy'
      exit 0
    else
      echo \"Attempt \$i/10: Frontend not responding, waiting...\"
      sleep 3
    fi
  done
  
  echo '❌ Frontend health check failed'
  exit 1
"

echo "✅ Frontend deployment completed!"
