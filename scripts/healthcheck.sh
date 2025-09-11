#!/bin/bash

SERVICE=$1
ENV=$2
VM_HOST=$3

if [ "$#" -ne 3 ]; then
    echo "Usage: $0 <service> <environment> <vm_host>"
    exit 1
fi

echo "Health checking $SERVICE in $ENV environment on $VM_HOST"

case $SERVICE in
  "frontend")
    HEALTH_URL="http://localhost/"
    ;;
  "backend")
    HEALTH_URL="http://localhost:8080/health"
    FALLBACK_URL="http://localhost:8080/"
    ;;
  *)
    echo "Unknown service: $SERVICE"
    exit 1
    ;;
esac

for i in {1..10}; do
  echo "Attempt $i/10..."
  
  if ssh -o StrictHostKeyChecking=no ubuntu@$VM_HOST "curl -f -s $HEALTH_URL > /dev/null"; then
    echo "$SERVICE is healthy!"
    exit 0
  elif [ "$SERVICE" = "backend" ] && ssh -o StrictHostKeyChecking=no ubuntu@$VM_HOST "curl -f -s $FALLBACK_URL > /dev/null"; then
    echo "$SERVICE is responding!"
    exit 0
  else
    echo "$SERVICE not responding, waiting..."
    sleep 5
  fi
done

echo "$SERVICE health check failed"
exit 1