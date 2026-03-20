#!/bin/bash

# =============================================================================
#   Standalone Test: PUT /api/users (update email + password)
# =============================================================================

set -u

BASE_URL="http://localhost:8080"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}=== TEST: PUT /api/users (update user) ===${NC}"
echo "Started: $(date)"
echo ""

# ────────────────────────────────────────────────
# 1. Reset DB
# ────────────────────────────────────────────────
echo "1. Reset database"
curl -s -i -X POST "${BASE_URL}/admin/reset" | head -n 3
echo ""

# ────────────────────────────────────────────────
# 2. Create test user
# ────────────────────────────────────────────────
echo "2. Create test user"
CREATE_RESP=$(curl -s -X POST "${BASE_URL}/api/users" \
  -H "Content-Type: application/json" \
  -d '{
    "email": "update-test-old@example.com",
    "password": "original-password-2026"
  }')

USER_ID=$(echo "$CREATE_RESP" | grep -oE '"id":"[0-9a-f-]{36}"' | cut -d'"' -f4)

if [ -z "$USER_ID" ]; then
  echo -e "${RED}Failed to create user or parse ID${NC}"
  echo "$CREATE_RESP"
  exit 1
fi

echo -e "User ID:          ${GREEN}$USER_ID${NC}"
echo ""

# ────────────────────────────────────────────────
# 3. Login to get access token
# ────────────────────────────────────────────────
echo "3. Login → get access token"
LOGIN_RESP=$(curl -s -X POST "${BASE_URL}/api/login" \
  -H "Content-Type: application/json" \
  -d '{
    "email":    "update-test-old@example.com",
    "password": "original-password-2026"
  }')

ACCESS_TOKEN=$(echo "$LOGIN_RESP" | grep -oE '"token":"[^"]+"' | cut -d'"' -f4)

if [ -z "$ACCESS_TOKEN" ]; then
  echo -e "${RED}Failed to login or extract access token${NC}"
  echo "$LOGIN_RESP"
  exit 1
fi

echo -e "Access token:     ${GREEN}${ACCESS_TOKEN:0:12}...${NC}"
echo ""

# ────────────────────────────────────────────────
# 4. Happy path: Update email + password
# ────────────────────────────────────────────────
echo "4. PUT /api/users → update email & password → should 200"
UPDATE_RESP=$(curl -s -X PUT "${BASE_URL}/api/users" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -d '{
    "email":    "update-test-new@example.com",
    "password": "new-secure-password-2026"
  }')

echo "$UPDATE_RESP" | grep -E '"id"|"email"|"created_at"|"updated_at"' --color=always || echo "$UPDATE_RESP"

UPDATED_EMAIL=$(echo "$UPDATE_RESP" | grep -oE '"email":"[^"]+"' | cut -d'"' -f4)

if [ "$UPDATED_EMAIL" != "update-test-new@example.com" ]; then
  echo -e "${RED}Email was not updated correctly${NC}"
  exit 1
fi

echo -e "${GREEN}Update successful – new email: $UPDATED_EMAIL${NC}"
echo ""

# ────────────────────────────────────────────────
# 5. Verify new credentials work (login again)
# ────────────────────────────────────────────────
echo "5. Login with new credentials → should succeed"
curl -s -i -X POST "${BASE_URL}/api/login" \
  -H "Content-Type: application/json" \
  -d '{
    "email":    "update-test-new@example.com",
    "password": "new-secure-password-2026"
  }' | head -n 10 | grep -E "HTTP/|token|refresh_token" --color=always
echo ""

# ────────────────────────────────────────────────
# 6. Try update without token → 401
# ────────────────────────────────────────────────
echo "6. PUT /api/users (no token) → should 401"
curl -s -i -X PUT "${BASE_URL}/api/users" \
  -H "Content-Type: application/json" \
  -d '{"email":"should-fail.com","password":"no"}' | head -n 8
echo ""

# ────────────────────────────────────────────────
# 7. Try update with invalid JSON → 400
# ────────────────────────────────────────────────
echo "7. PUT /api/users invalid JSON → should 400"
curl -s -i -X PUT "${BASE_URL}/api/users" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -d '{email: "broken"}' | head -n 6
echo ""

# ────────────────────────────────────────────────
# 8. (Optional) Try update with same email + empty password
# ────────────────────────────────────────────────
echo "8. PUT /api/users same email + empty password → observe behavior"
curl -s -X PUT "${BASE_URL}/api/users" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -d '{
    "email":    "update-test-new@example.com",
    "password": ""
  }' | head -n 12
echo ""

echo -e "${GREEN}Test finished.${NC}\n"
echo "Quick checks:"
echo "  • 200 response contains updated user (new email, new updated_at)?"
echo "  • Can login with new email + new password?"
echo "  • Old password no longer works? (manual check if desired)"
echo "  • 401 when no/malformed token?"
echo "  • 400 on bad JSON?"
echo "  • Server logs clean (no panics, no sql errors)?"
echo ""