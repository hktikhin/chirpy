#!/bin/bash

# =============================================================================
#   Chirpy – Standalone Test: GET /api/chirps endpoint
#   (independent from other test files)
# =============================================================================

set -u  # treat unset variables as error

BASE_URL="http://localhost:8080"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${YELLOW}=== STANDALONE CHIRPS LIST TEST ===${NC}"
echo "Started: $(date)"
echo "Base URL: $BASE_URL"
echo ""

# ────────────────────────────────────────────────
echo "1. Reset database (clean state)"
echo "   → Expect 200 OK when PLATFORM=dev"
RESET_OUT=$(curl -s -i -X POST "${BASE_URL}/admin/reset")
echo "$RESET_OUT" | head -n 3
echo ""

# ────────────────────────────────────────────────
echo "2. Create test user A"
USER_A_RESP=$(curl -s -X POST "${BASE_URL}/api/users" \
  -H "Content-Type: application/json" \
  -d '{"email": "chirps-test-a@example.com"}')

USER_A_ID=$(echo "$USER_A_RESP" | grep -oE '"id":"[0-9a-f-]{36}"' | cut -d'"' -f4)

if [ -z "$USER_A_ID" ]; then
  echo -e "${RED}Failed to create user A or extract ID${NC}"
  echo "Response:"
  echo "$USER_A_RESP" | head -n 8
  exit 1
fi

echo -e "User A ID: ${GREEN}$USER_A_ID${NC}"
echo ""

# ────────────────────────────────────────────────
echo "3. Create 3 chirps (different content & natural time order)"
echo "   → Should appear in created_at ASC order"

curl -s -X POST "${BASE_URL}/api/chirps" \
  -H "Content-Type: application/json" \
  -d "{\"body\": \"First chirp ever!\", \"user_id\": \"${USER_A_ID}\"}" > /dev/null

sleep 1   # give DB a moment → ensure different timestamps

curl -s -X POST "${BASE_URL}/api/chirps" \
  -H "Content-Type: application/json" \
  -d "{\"body\": \"Second – with some kerfuffle\", \"user_id\": \"${USER_A_ID}\"}" > /dev/null

sleep 1

curl -s -X POST "${BASE_URL}/api/chirps" \
  -H "Content-Type: application/json" \
  -d "{\"body\": \"Third one – testing sort order\", \"user_id\": \"${USER_A_ID}\"}" > /dev/null

echo "Created 3 chirps (sleep between to ensure time ordering)"
echo ""

# ────────────────────────────────────────────────
echo "4. GET /api/chirps – should return array of 3 chirps, oldest first"
echo -e "${YELLOW}Expected:${NC} HTTP 200 + JSON array with 3 objects"
echo ""

GET_OUT=$(curl -s -i "${BASE_URL}/api/chirps")

echo "$GET_OUT" | head -n 12
echo "... (showing first lines)"
echo ""

echo -e "${GREEN}Standalone chirps list test finished.${NC}"
echo ""
echo "Quick reminders / debug tips:"
echo "  • 404 → check mux.HandleFunc(\"GET /api/chirps\", ...) – no trailing space!"
echo "  • 500 → look at server logs (sqlc generate run? query matches?)"
echo "  • Wrong order → ORDER BY created_at ASC missing or wrong"
echo ""