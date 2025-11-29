#!/bin/bash
set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INFRA_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
ENV_FILE="$INFRA_DIR/.env.bigpods.local"
ENV_EXAMPLE="$INFRA_DIR/.env.bigpods.example"

echo -e "${BLUE}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  DreamScape - Development Secrets Generator         ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════╝${NC}\n"

# Check if .env.bigpods.local exists
if [ -f "$ENV_FILE" ]; then
    echo -e "${YELLOW}⚠️  .env.bigpods.local already exists!${NC}"
    read -p "Do you want to regenerate secrets? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Cancelled. Existing secrets kept.${NC}"
        exit 0
    fi

    # Backup existing file
    BACKUP_FILE="$ENV_FILE.backup.$(date +%s)"
    cp "$ENV_FILE" "$BACKUP_FILE"
    echo -e "${GREEN}✓ Backup created: ${BACKUP_FILE}${NC}\n"
fi

# Function to generate random secret
generate_secret() {
    local length=${1:-32}
    openssl rand -base64 "$length" | tr -d '\n'
}

echo -e "${YELLOW}🔐 Generating strong secrets...${NC}\n"

# Copy example file
cp "$ENV_EXAMPLE" "$ENV_FILE"

# Generate secrets
DB_PASSWORD=$(generate_secret 32)
REDIS_PASSWORD=$(generate_secret 32)
JWT_SECRET=$(generate_secret 64)
SESSION_SECRET=$(generate_secret 64)
S3_ACCESS_KEY=$(generate_secret 20)
S3_SECRET_KEY=$(generate_secret 40)

# Replace weak secrets in .env.bigpods.local
sed -i.tmp "s/DB_PASSWORD=prod123.*/DB_PASSWORD=${DB_PASSWORD}/" "$ENV_FILE"
sed -i.tmp "s/REDIS_PASSWORD=.*/REDIS_PASSWORD=${REDIS_PASSWORD}/" "$ENV_FILE"
sed -i.tmp "s/JWT_SECRET=prod-jwt-secret-change-in-production.*/JWT_SECRET=${JWT_SECRET}/" "$ENV_FILE"
sed -i.tmp "s/SESSION_SECRET=prod-session-secret-change-in-production.*/SESSION_SECRET=${SESSION_SECRET}/" "$ENV_FILE"
sed -i.tmp "s/S3_ACCESS_KEY=dreamscape-prod.*/S3_ACCESS_KEY=${S3_ACCESS_KEY}/" "$ENV_FILE"
sed -i.tmp "s/S3_SECRET_KEY=dreamscape-prod-secret.*/S3_SECRET_KEY=${S3_SECRET_KEY}/" "$ENV_FILE"

# Remove temporary files
rm -f "$ENV_FILE.tmp"

echo -e "${GREEN}✓ Generated Database Password (32 bytes)${NC}"
echo -e "${GREEN}✓ Generated Redis Password (32 bytes)${NC}"
echo -e "${GREEN}✓ Generated JWT Secret (64 bytes)${NC}"
echo -e "${GREEN}✓ Generated Session Secret (64 bytes)${NC}"
echo -e "${GREEN}✓ Generated S3 Access Key (20 bytes)${NC}"
echo -e "${GREEN}✓ Generated S3 Secret Key (40 bytes)${NC}"

echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✅ Secrets generated successfully!${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

echo -e "${YELLOW}📝 Next steps:${NC}"
echo -e "  1. Review .env.bigpods.local and add your API keys:"
echo -e "     - AMADEUS_API_KEY / AMADEUS_API_SECRET"
echo -e "     - STRIPE_SECRET_KEY / STRIPE_PUBLISHABLE_KEY"
echo -e "     - OPENAI_API_KEY"
echo -e "  2. Start Big Pods: ./scripts/bigpods/prod-bigpods.sh"
echo -e "\n${RED}⚠️  IMPORTANT: Never commit .env.bigpods.local to Git!${NC}\n"