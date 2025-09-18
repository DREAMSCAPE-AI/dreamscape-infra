#!/bin/bash
set -e

ENV=$1
SERVICES=$2
VM_HOST=$3
SSH_KEY_FILE=$4

if [ "$#" -ne 4 ]; then
    echo "Usage: $0 <environment> <services> <vm_host> <ssh_key_file>"
    exit 1
fi

echo "Starting rollback for $ENV environment"
echo "Services: $SERVICES"
echo "Key: $SSH_KEY_FILE"

rollback_service() {
  local service=$1
  echo "Rolling back $service..."
  
  ssh -i "$SSH_KEY_FILE" -o StrictHostKeyChecking=no ubuntu@$VM_HOST "
    docker stop dreamscape-$service-$ENV 2>/dev/null || echo 'No current container'
    docker rm dreamscape-$service-$ENV 2>/dev/null || echo 'No container to remove'
    
    previous_tag=\$(docker images dreamscape/$service --format 'table {{.Tag}}' | grep -v latest | grep -v TAG | head -1)
    
    if [ -z \"\$previous_tag\" ]; then
      echo 'No previous version found for $service'
      exit 1
    fi
    
    echo \"Rolling back to: dreamscape/$service:\$previous_tag\"
    
    case '$service' in
      'frontend')
        docker run -d \
          --name dreamscape-$service-$ENV \
          --restart unless-stopped \
          -p 80:80 \
          -e NODE_ENV=$ENV \
          dreamscape/$service:\$previous_tag
        ;;
      'backend')
        docker run -d \
          --name dreamscape-$service-$ENV \
          --restart unless-stopped \
          -p 8080:8080 \
          -e NODE_ENV=$ENV \
          dreamscape/$service:\$previous_tag
        ;;
    esac
  "
}

IFS=',' read -ra SERVICE_ARRAY <<< "$SERVICES"
for service in "${SERVICE_ARRAY[@]}"; do
  rollback_service "$service"
done

echo "✅ Rollback completed!"
