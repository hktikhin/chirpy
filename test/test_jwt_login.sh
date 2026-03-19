#!/usr/bin/env bash

# =============================================================================
#   Chirpy – Standalone Test: User + Login + Create Chirp (authenticated)
#   Tests: POST /api/users, POST /api/login, POST /api/chirps (with Bearer)
# =============================================================================

set -u    # treat unset variables as error

BASE_URL="http://localhost:8080"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${YELLOW}=== STANDALONE: USER + LOGIN + AUTHENTICATED CHIRP TEST ===${NC}"
echo "Started: $(date)"
echo "Base URL: $BASE_URL"
echo ""

# ────────────────────────────────────────────────
echo "1. Reset database (clean state)"
RESET_OUT=$(curl -s -i -X POST "${BASE_URL}/admin/reset")
echo "$RESET_OUT" | head -n 1
echo ""

# ────────────────────────────────────────────────
echo "2. Create test user"
TEST_EMAIL="chirp-test-$(date +%s)@example.com"
TEST_PASSWORD="correct-horse-battery-9876"

echo "Email:    $TEST_EMAIL"
echo "Password: $TEST_PASSWORD (not echoed in real apps!)"
echo ""

CREATE_RESP=$(curl -s -X POST "${BASE_URL}/api/users" \
  -H "Content-Type: application/json" \
  -d "{\"email\": \"${TEST_EMAIL}\", \"password\": \"${TEST_PASSWORD}\"}")

USER_ID=$(echo "$CREATE_RESP" | grep -oE '"id":"[0-9a-f-]{36}"' | cut -d'"' -f4 || true)

if [ -z "$USER_ID" ]; then
  echo -e "${RED}Failed to create user or extract ID${NC}"
  echo "Response:"
  echo "$CREATE_RESP" | head -n 10
  exit 1
fi

echo -e "User created → ID: ${GREEN}${USER_ID}${NC}"
echo ""

# ────────────────────────────────────────────────
echo "3. Login → get JWT token"
LOGIN_RESP=$(curl -s -X POST "${BASE_URL}/api/login" \
  -H "Content-Type: application/json" \
  -d "{\"email\": \"${TEST_EMAIL}\", \"password\": \"${TEST_PASSWORD}\"}")

TOKEN=$(echo "$LOGIN_RESP" | grep -oE '"token":"[^"]+"' | cut -d'"' -f4 || true)

if [ -z "$TOKEN" ]; then
  echo -e "${RED}Login failed – no token received${NC}"
  echo "Response:"
  echo "$LOGIN_RESP" | head -n 10
  exit 1
fi

echo -e "${GREEN}Login OK${NC} — token starts with: ${TOKEN:0:15}..."
echo ""

# ────────────────────────────────────────────────
echo "4. Create one chirp using Bearer token (user_id from JWT)"
CHIRP_BODY="Authenticated chirp at $(date '+%Y-%m-%d %H:%M:%S')"

CREATE_CHIRP_RESP=$(curl -s -X POST "${BASE_URL}/api/chirps" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${TOKEN}" \
  -d "{
    \"body\": \"${CHIRP_BODY}\",
    \"user_id\": \"${USER_ID}\"
  }")

CHIRP_ID=$(echo "$CREATE_CHIRP_RESP" | grep -oE '"id":"[0-9a-f-]{36}"' | cut -d'"' -f4 || true)

if [ -z "$CHIRP_ID" ]; then
  echo -e "${RED}Failed to create chirp${NC}"
  echo "Response:"
  echo "$CREATE_CHIRP_RESP" | head -n 10
  echo ""
  echo "Server likely logs: foreign key violation → check if user_id is taken from token"
  exit 1
fi

echo -e "${GREEN}Chirp created OK${NC} — ID: ${CHIRP_ID}"
echo "Content: \"${CHIRP_BODY}\""
echo ""

# ────────────────────────────────────────────────
echo "5. List all chirps → should see our new chirp"
echo -e "${YELLOW}Expected:${NC} 200 + array with at least 1 chirp"
echo ""

LIST_OUT=$(curl -s -i "${BASE_URL}/api/chirps")

echo "$LIST_OUT" | head -n 1
echo "$LIST_OUT" | tail -n +2 | head -n 12
echo "..."

echo ""
echo -e "${GREEN}Test finished.${NC}"
echo ""
echo "Quick debug checklist:"
echo "  • 401 on POST /api/chirps → check GetBearerToken / ValidateJWT"
echo "  • 400 → body missing or malformed JSON"
echo "  • 500 → look at server logs (user_id from token not found?)"
echo "  • Chirp missing in list → check database insert / query"
echo "  • Token invalid → TOKEN_SECRET env var set correctly?"
echo ""