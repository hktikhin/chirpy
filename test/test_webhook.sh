#!/bin/bash

# =============================================================================
#   Clean Test: POST /api/polka/webhooks - Chirpy Red Upgrade
#   (No GET /api/users endpoint - using login + update pattern)
# =============================================================================

set -u

BASE_URL="http://localhost:8080"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}=== TEST: POST /api/polka/webhooks (Chirpy Red Upgrade) ===${NC}"
echo "Started: $(date)"
echo ""

# 1. Reset Database
echo "1. Resetting database..."
curl -s -i -X POST "${BASE_URL}/admin/reset" | head -n 3
echo ""

# 2. Create test user
echo "2. Creating test user..."
CREATE_RESP=$(curl -s -X POST "${BASE_URL}/api/users" \
  -H "Content-Type: application/json" \
  -d '{
    "email": "chirpy-red-test@example.com",
    "password": "super-secret-2026"
  }')

USER_ID=$(echo "$CREATE_RESP" | grep -oE '"id":"[0-9a-f-]{36}"' | cut -d'"' -f4)

if [ -z "$USER_ID" ]; then
  echo -e "${RED}Failed to create user or extract ID${NC}"
  echo "$CREATE_RESP"
  exit 1
fi

echo -e "Created User ID : ${GREEN}$USER_ID${NC}"
echo ""

# 3. Send Polka Webhook (safe JSON)
echo "3. Sending Polka webhook (user.upgraded)..."
WEBHOOK_RESP=$(curl -s -i -X POST "${BASE_URL}/api/polka/webhooks" \
  -H "Content-Type: application/json" \
  --data-binary @- << EOF
{
  "event": "user.upgraded",
  "data": {
    "user_id": "$USER_ID"
  }
}
EOF
)

echo "$WEBHOOK_RESP" | head -n 12

if echo "$WEBHOOK_RESP" | grep -q "204 No Content"; then
  echo -e "${GREEN}✓ Webhook returned 204 No Content${NC}"
else
  echo -e "${RED}✗ Webhook failed${NC}"
  echo "Full response:"
  echo "$WEBHOOK_RESP"
  exit 1
fi
echo ""

# 4. Login to get fresh token
echo "4. Logging in to get access token..."
LOGIN_RESP=$(curl -s -X POST "${BASE_URL}/api/login" \
  -H "Content-Type: application/json" \
  -d '{
    "email": "chirpy-red-test@example.com",
    "password": "super-secret-2026"
  }')

TOKEN=$(echo "$LOGIN_RESP" | grep -oE '"token":"[^"]+"' | cut -d'"' -f4)

if [ -z "$TOKEN" ]; then
  echo -e "${RED}Failed to get access token${NC}"
  echo "$LOGIN_RESP"
  exit 1
fi

echo -e "Access token acquired${NC}"
echo ""

# 5. Update user (using your existing PUT /api/users) to force a response that includes is_chirpy_red
echo "5. Updating user via PUT /api/users to check is_chirpy_red..."
UPDATE_RESP=$(curl -s -X PUT "${BASE_URL}/api/users" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{
    "email": "chirpy-red-test@example.com",
    "password": "super-secret-2026"
  }')

echo "$UPDATE_RESP"

if echo "$UPDATE_RESP" | grep -q '"is_chirpy_red":true'; then
  echo -e "${GREEN}✓ SUCCESS: User is now Chirpy Red!${NC}"
elif echo "$UPDATE_RESP" | grep -q '"is_chirpy_red":false'; then
  echo -e "${RED}✗ Upgrade did NOT work - is_chirpy_red is still false${NC}"
else
  echo -e "${YELLOW}Warning: Could not find is_chirpy_red field in response${NC}"
  echo "Response was:"
  echo "$UPDATE_RESP"
fi

echo -e "\n${GREEN}Test completed.${NC}"
echo "Check server logs for UpgradeUserToRed call."