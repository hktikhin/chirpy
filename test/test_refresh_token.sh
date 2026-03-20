#!/bin/bash

# =============================================================================
#   Standalone Test: Authentication endpoints (login / refresh / revoke)
# =============================================================================

set -u

BASE_URL="http://localhost:8080"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}=== TEST: Authentication (login / refresh / revoke) ===${NC}"
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
USER_RESP=$(curl -s -X POST "${BASE_URL}/api/users" \
  -H "Content-Type: application/json" \
  -d '{
    "email": "auth-test@example.com",
    "password": "correct-horse-battery-staple-2025"
  }')

USER_ID=$(echo "$USER_RESP" | grep -oE '"id":"[0-9a-f-]{36}"' | cut -d'"' -f4)

if [ -z "$USER_ID" ]; then
  echo -e "${RED}Failed to create user or parse ID${NC}"
  echo "$USER_RESP"
  exit 1
fi

echo -e "User ID:        ${GREEN}$USER_ID${NC}"
echo ""

# ────────────────────────────────────────────────
# 3. Login → get access + refresh token
# ────────────────────────────────────────────────
echo "3. POST /api/login → should 200 + return token + refresh_token"
LOGIN_RESP=$(curl -s -X POST "${BASE_URL}/api/login" \
  -H "Content-Type: application/json" \
  -d '{
    "email":    "auth-test@example.com",
    "password": "correct-horse-battery-staple-2025"
  }')

echo "$LOGIN_RESP" | grep -E '"token"|"refresh_token"' --color=always || echo -e "${YELLOW}(raw response below)${NC}"
echo "$LOGIN_RESP"

ACCESS_TOKEN=$(echo "$LOGIN_RESP" | grep -oE '"token":"[^"]+"' | cut -d'"' -f4)
REFRESH_TOKEN=$(echo "$LOGIN_RESP" | grep -oE '"refresh_token":"[^"]+"' | cut -d'"' -f4)

if [ -z "$ACCESS_TOKEN" ] || [ -z "$REFRESH_TOKEN" ]; then
  echo -e "${RED}Failed to extract access_token or refresh_token${NC}"
  exit 1
fi

echo -e "Access token:   ${GREEN}${ACCESS_TOKEN:0:12}...${NC}"
echo -e "Refresh token:  ${GREEN}${REFRESH_TOKEN:0:12}...${NC}"
echo ""

# ────────────────────────────────────────────────
# 4. Refresh → get new access token
# ────────────────────────────────────────────────
echo "4. POST /api/refresh → should 200 + new access token"
REFRESH_RESP=$(curl -s -X POST "${BASE_URL}/api/refresh" \
  -H "Authorization: Bearer ${REFRESH_TOKEN}")

echo "$REFRESH_RESP" | grep -E '"token"' --color=always || echo -e "${YELLOW}(raw response below)${NC}"
echo "$REFRESH_RESP"

NEW_ACCESS_TOKEN=$(echo "$REFRESH_RESP" | grep -oE '"token":"[^"]+"' | cut -d'"' -f4)

if [ -z "$NEW_ACCESS_TOKEN" ]; then
  echo -e "${RED}Failed to get new access token from refresh${NC}"
  exit 1
fi

echo -e "New access token: ${GREEN}${NEW_ACCESS_TOKEN:0:12}...${NC}"
echo ""

# ────────────────────────────────────────────────
# 5. Revoke → should 204 No Content
# ────────────────────────────────────────────────
echo "5. POST /api/revoke → should 204"
REVOKE_RESP=$(curl -s -i -X POST "${BASE_URL}/api/revoke" \
  -H "Authorization: Bearer ${REFRESH_TOKEN}")

echo "$REVOKE_RESP" | head -n 5

if ! echo "$REVOKE_RESP" | grep -q "HTTP/1.1 204"; then
  echo -e "${RED}Expected 204 No Content, got something else${NC}"
  echo "$REVOKE_RESP"
  exit 1
fi

echo -e "${GREEN}Revoke successful (204)${NC}"
echo ""

# ────────────────────────────────────────────────
# 6. Try refresh again → should now fail (401)
# ────────────────────────────────────────────────
echo "6. POST /api/refresh with revoked token → should 401"
curl -s -i -X POST "${BASE_URL}/api/refresh" \
  -H "Authorization: Bearer ${REFRESH_TOKEN}" | head -n 8
echo ""

# ────────────────────────────────────────────────
# 7. Try login with wrong password → 401
# ────────────────────────────────────────────────
echo "7. POST /api/login wrong password → should 401"
curl -s -i -X POST "${BASE_URL}/api/login" \
  -H "Content-Type: application/json" \
  -d '{
    "email":    "auth-test@example.com",
    "password": "wrong-password"
  }' | head -n 8
echo ""

# ────────────────────────────────────────────────
# 8. Try refresh without token → 401
# ────────────────────────────────────────────────
echo "8. POST /api/refresh no Authorization header → should 401"
curl -s -i -X POST "${BASE_URL}/api/refresh" 
echo ""

echo -e "${GREEN}Test finished.${NC}\n"
echo "Quick checks:"
echo "  • Login returns both token and refresh_token?"
echo "  • Refresh returns new access token?"
echo "  • Revoke returns 204 and makes refresh fail afterward?"
echo "  • Wrong password → 401?"
echo "  • Missing/empty token → 401?"
echo "  • Server logs show no panics/unexpected errors?"
echo ""