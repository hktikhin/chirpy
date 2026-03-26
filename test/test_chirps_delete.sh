#!/bin/bash

# =============================================================================
#   Standalone Test: DELETE /api/chirps/{chirpID}
# =============================================================================

set -u

BASE_URL="http://localhost:8080"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}=== TEST: DELETE /api/chirps/{chirpID} ===${NC}"
echo "Started: $(date)"
echo ""

# ────────────────────────────────────────────────
# 1. Reset DB
# ────────────────────────────────────────────────
echo "1. Reset database"
curl -s -i -X POST "${BASE_URL}/admin/reset" | head -n 3
echo ""

# ────────────────────────────────────────────────
# 2. Create main test user
# ────────────────────────────────────────────────
echo "2. Create main test user"
CREATE_RESP=$(curl -s -X POST "${BASE_URL}/api/users" \
  -H "Content-Type: application/json" \
  -d '{
    "email": "delete-chirp-test@example.com",
    "password": "original-password-2026"
  }')

USER_ID=$(echo "$CREATE_RESP" | grep -oE '"id":"[0-9a-f-]{36}"' | cut -d'"' -f4)

if [ -z "$USER_ID" ]; then
  echo -e "${RED}Failed to create user${NC}"
  exit 1
fi

echo -e "Main User ID:     ${GREEN}$USER_ID${NC}"
echo ""

# ────────────────────────────────────────────────
# 3. Login as main user → get token
# ────────────────────────────────────────────────
echo "3. Login as main user"
LOGIN_RESP=$(curl -s -X POST "${BASE_URL}/api/login" \
  -H "Content-Type: application/json" \
  -d '{
    "email":    "delete-chirp-test@example.com",
    "password": "original-password-2026"
  }')

ACCESS_TOKEN=$(echo "$LOGIN_RESP" | grep -oE '"token":"[^"]+"' | cut -d'"' -f4)

if [ -z "$ACCESS_TOKEN" ]; then
  echo -e "${RED}Failed to get access token${NC}"
  exit 1
fi

echo -e "Access token:     ${GREEN}${ACCESS_TOKEN:0:12}...${NC}"
echo ""

# ────────────────────────────────────────────────
# 4. Create chirp owned by main user
# ────────────────────────────────────────────────
echo "4. Create chirp owned by main user"
CHIRP_RESP=$(curl -s -X POST "${BASE_URL}/api/chirps" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -d "{\"body\": \"My own chirp that I can delete.\", \"user_id\": \"${USER_ID}\"}")

CHIRP_ID=$(echo "$CHIRP_RESP" | grep -oE '"id":"[0-9a-f-]{36}"' | cut -d'"' -f4)

if [ -z "$CHIRP_ID" ]; then
  echo -e "${RED}Failed to create chirp${NC}"
  echo "$CHIRP_RESP"
  exit 1
fi

echo -e "Chirp ID:         ${GREEN}$CHIRP_ID${NC}"
echo ""

# ────────────────────────────────────────────────
# 5. Happy path: Delete own chirp → 204
# ────────────────────────────────────────────────
echo "5. DELETE own chirp → should 204"
DELETE_RESP=$(curl -s -i -X DELETE "${BASE_URL}/api/chirps/${CHIRP_ID}" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}")

echo "$DELETE_RESP" | head -n 8

if echo "$DELETE_RESP" | head -n 1 | grep -q "204"; then
  echo -e "${GREEN}✓ 204 No Content - Own chirp deleted successfully${NC}"
else
  echo -e "${RED}✗ Expected 204${NC}"
fi
echo ""

echo "   Verify deletion (GET should 404):"
curl -s -i "${BASE_URL}/api/chirps/${CHIRP_ID}" | head -n 6
echo ""

# ────────────────────────────────────────────────
# 6–9. Other negative cases (404, 400, 401)
# ────────────────────────────────────────────────
echo "6. DELETE non-existent chirp → should 404"
FAKE_ID="11111111-2222-3333-4444-555555555555"
curl -s -i -X DELETE "${BASE_URL}/api/chirps/${FAKE_ID}" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" | head -n 8
echo ""

echo "7. DELETE invalid UUID → should 400"
curl -s -i -X DELETE "${BASE_URL}/api/chirps/not-a-uuid" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" | head -n 8
echo ""

echo "8. DELETE without token → should 401"
curl -s -i -X DELETE "${BASE_URL}/api/chirps/${CHIRP_ID}" | head -n 8
echo ""

# ────────────────────────────────────────────────
# 10. Proper permission test (403)
# ────────────────────────────────────────────────
echo "10. Permission test: Try to delete another user's chirp → should 403"

# Create second user
echo "   Creating second user..."
OTHER_CREATE=$(curl -s -X POST "${BASE_URL}/api/users" \
  -H "Content-Type: application/json" \
  -d '{
    "email": "other-user-delete-test@example.com",
    "password": "original-password-2026"
  }')

OTHER_USER_ID=$(echo "$OTHER_CREATE" | grep -oE '"id":"[0-9a-f-]{36}"' | cut -d'"' -f4)

# Login as second user to get their token
OTHER_LOGIN=$(curl -s -X POST "${BASE_URL}/api/login" \
  -H "Content-Type: application/json" \
  -d '{
    "email": "other-user-delete-test@example.com",
    "password": "original-password-2026"
  }')

OTHER_TOKEN=$(echo "$OTHER_LOGIN" | grep -oE '"token":"[^"]+"' | cut -d'"' -f4)

# Create chirp owned by second user (using second user's token)
OTHER_CHIRP_RESP=$(curl -s -X POST "${BASE_URL}/api/chirps" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${OTHER_TOKEN}" \
  -d "{\"body\": \"This chirp belongs to the other user.\", \"user_id\": \"${OTHER_USER_ID}\"}")

OTHER_CHIRP_ID=$(echo "$OTHER_CHIRP_RESP" | grep -oE '"id":"[0-9a-f-]{36}"' | cut -d'"' -f4)

if [ -n "$OTHER_CHIRP_ID" ]; then
  echo -e "   Other chirp ID: ${GREEN}$OTHER_CHIRP_ID${NC}"
  echo "   Trying to delete it using main user's token (expect 403)..."
  
  curl -s -i -X DELETE "${BASE_URL}/api/chirps/${OTHER_CHIRP_ID}" \
    -H "Authorization: Bearer ${ACCESS_TOKEN}" | head -n 10
else
  echo -e "${RED}   Failed to create other user's chirp${NC}"
fi

echo ""

echo -e "${GREEN}Test finished.${NC}\n"
echo "Quick checks:"
echo "  • 204 when deleting own chirp"
echo "  • 404 after deletion / on non-existent ID"
echo "  • 400 on bad UUID"
echo "  • 401 without token"
echo "  • 403 when deleting someone else's chirp ← this is the important one"
echo "  • Server logs show clean permission denial"
echo ""