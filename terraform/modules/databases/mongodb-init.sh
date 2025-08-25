#!/bin/bash
set -e

# Update system
apt-get update && apt-get upgrade -y

# Install MongoDB
wget -qO - https://www.mongodb.org/static/pgp/server-${mongodb_version}.asc | apt-key add -
echo "deb [ arch=amd64,arm64 ] https://repo.mongodb.org/apt/ubuntu jammy/mongodb-org/${mongodb_version} multiverse" | tee /etc/apt/sources.list.d/mongodb-org-${mongodb_version}.list
apt-get update
apt-get install -y mongodb-org

# Format and mount data volume
mkfs.ext4 /dev/sdb
mkdir -p /data/mongodb
mount /dev/sdb /data/mongodb
echo "/dev/sdb /data/mongodb ext4 defaults 0 0" >> /etc/fstab

# Set permissions
chown -R mongodb:mongodb /data/mongodb
chmod 755 /data/mongodb

# Configure MongoDB
cat > /etc/mongod.conf <<EOF
storage:
  dbPath: /data/mongodb
  journal:
    enabled: true

systemLog:
  destination: file
  logAppend: true
  path: /var/log/mongodb/mongod.log

net:
  port: 27017
  bindIp: 0.0.0.0

processManagement:
  fork: true
  pidFilePath: /var/run/mongodb/mongod.pid
  timeZoneInfo: /usr/share/zoneinfo

security:
  authorization: enabled

replication:
  replSetName: "${mongodb_replica_set}"

setParameter:
  authenticationMechanisms: SCRAM-SHA-1,SCRAM-SHA-256
EOF

# Start MongoDB
systemctl enable mongod
systemctl start mongod

# Wait for MongoDB to start
sleep 10

# Initialize replica set and create admin user
mongo --eval '
rs.initiate({
  _id: "${mongodb_replica_set}",
  members: [{ _id: 0, host: "localhost:27017" }]
});

use admin;
db.createUser({
  user: "${mongodb_admin_user}",
  pwd: "${mongodb_admin_pass}",
  roles: [
    { role: "userAdminAnyDatabase", db: "admin" },
    { role: "readWriteAnyDatabase", db: "admin" },
    { role: "dbAdminAnyDatabase", db: "admin" },
    { role: "clusterAdmin", db: "admin" }
  ]
});

use dreamscape_voyage;
db.createUser({
  user: "voyage_user",
  pwd: "${mongodb_admin_pass}",
  roles: [
    { role: "readWrite", db: "dreamscape_voyage" }
  ]
});
'

# Configure backup script
cat > /usr/local/bin/mongodb-backup.sh <<'EOF'
#!/bin/bash
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="/tmp/mongodb_backup_$DATE"
mkdir -p $BACKUP_DIR

mongodump --out $BACKUP_DIR
tar -czf /tmp/mongodb_backup_$DATE.tar.gz -C /tmp mongodb_backup_$DATE

# Upload to OCI Object Storage (requires oci-cli configured)
oci os object put --bucket-name "${project_name}-db-backups-${environment}" --file /tmp/mongodb_backup_$DATE.tar.gz --name "mongodb/mongodb_backup_$DATE.tar.gz"

# Cleanup
rm -rf $BACKUP_DIR /tmp/mongodb_backup_$DATE.tar.gz
EOF

chmod +x /usr/local/bin/mongodb-backup.sh

# Add cron job for daily backups
echo "0 2 * * * /usr/local/bin/mongodb-backup.sh" | crontab -

echo "MongoDB installation and configuration completed successfully!"