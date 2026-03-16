#!/bin/bash

# =============================================================================
#   Standalone Test: GET /api/chirps/{chirpID}
# =============================================================================

set -u

BASE_URL="http://localhost:8080"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}=== TEST: GET /api/chirps/{chirpID} ===${NC}"
echo "Started: $(date)"
echo ""

# 1. Reset DB
echo "1. Reset database"
curl -s -i -X POST "${BASE_URL}/admin/reset" | head -n 3
echo ""

# 2. Create one user
echo "2. Create test user"
USER_RESP=$(curl -s -X POST "${BASE_URL}/api/users" \
  -H "Content-Type: application/json" \
  -d '{"email": "get-chirp-test@example.com"}')

USER_ID=$(echo "$USER_RESP" | grep -oE '"id":"[0-9a-f-]{36}"' | cut -d'"' -f4)

if [ -z "$USER_ID" ]; then
  echo -e "${RED}Failed to create user or parse ID${NC}"
  echo "$USER_RESP"
  exit 1
fi

echo -e "User ID: ${GREEN}$USER_ID${NC}"
echo ""

# 3. Create two chirps → capture their IDs
echo "3. Create chirp #1"
CHIRP1_RESP=$(curl -s -X POST "${BASE_URL}/api/chirps" \
  -H "Content-Type: application/json" \
  -d "{\"body\": \"First chirp – should be findable\", \"user_id\": \"${USER_ID}\"}")

CHIRP1_ID=$(echo "$CHIRP1_RESP" | grep -oE '"id":"[0-9a-f-]{36}"' | cut -d'"' -f4)

if [ -z "$CHIRP1_ID" ]; then
  echo -e "${RED}Failed to create chirp 1 or parse ID${NC}"
  echo "$CHIRP1_RESP"
  exit 1
fi

echo -e "Chirp 1 ID: ${GREEN}$CHIRP1_ID${NC}"

sleep 1  # ensure different timestamp

echo "   Create chirp #2"
CHIRP2_RESP=$(curl -s -X POST "${BASE_URL}/api/chirps" \
  -H "Content-Type: application/json" \
  -d "{\"body\": \"Second chirp – different content\", \"user_id\": \"${USER_ID}\"}")

CHIRP2_ID=$(echo "$CHIRP2_RESP" | grep -oE '"id":"[0-9a-f-]{36}"' | cut -d'"' -f4)

echo -e "Chirp 2 ID: ${GREEN}$CHIRP2_ID${NC}"
echo ""

# 4. Test happy path – get existing chirp
echo "4. GET /api/chirps/$CHIRP1_ID → should 200"
curl -s -i "${BASE_URL}/api/chirps/${CHIRP1_ID}" | head -n 12
echo ""

# 5. Get the second one
echo "5. GET /api/chirps/$CHIRP2_ID → should 200"
curl -s -i "${BASE_URL}/api/chirps/${CHIRP2_ID}" | head -n 12
echo ""

# 6. Get non-existing chirp → 404
FAKE_ID="11111111-2222-3333-4444-555555555555"
echo "6. GET /api/chirps/$FAKE_ID (non-existing) → should 404"
curl -s -i "${BASE_URL}/api/chirps/${FAKE_ID}" | head -n 5
echo ""

# 7. Invalid UUID format → should 400
echo "7. GET /api/chirps/not-a-uuid → should 400"
curl -s -i "${BASE_URL}/api/chirps/not-a-uuid" | head -n 5
echo ""

# 8. Missing ID (just /api/chirps/) → 404 (mux won't match)
echo "8. GET /api/chirps/ (no ID) → should 404"
curl -s -i "${BASE_URL}/api/chirps/" | head -n 3
echo ""

echo -e "${GREEN}Test finished.${NC}\n"
echo "Quick checks:"
echo "  • 200 responses contain correct chirp data?"
echo "  • 404 for unknown ID?"
echo "  • 400 for bad UUID?"
echo "  • Server logs show no unexpected errors?"
echo ""