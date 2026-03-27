#!/bin/bash

# =============================================================================
#   Clean Test: POST /api/polka/webhooks - Chirpy Red Upgrade
# =============================================================================

set -u

BASE_URL="http://localhost:8080"
# --- 使用你提供的具体 API KEY ---
POLKA_KEY="xxxxx" 

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}=== TEST: POST /api/polka/webhooks (Chirpy Red Upgrade) ===${NC}"
echo "Started: $(date)"
echo ""

# 1. 重置数据库
echo "1. Resetting database..."
curl -s -i -X POST "${BASE_URL}/admin/reset" | head -n 3
echo ""

# 2. 创建测试用户
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

# 3a. 负面测试：验证 API Key 缺失或错误时是否报错 401
echo "3a. Testing webhook WITHOUT/WRONG API Key (Should fail with 401)..."
BAD_AUTH_RESP=$(curl -s -i -X POST "${BASE_URL}/api/polka/webhooks" \
  -H "Content-Type: application/json" \
  -H "Authorization: ApiKey WRONG_KEY" \
  -d "{
    \"event\": \"user.upgraded\",
    \"data\": { \"user_id\": \"$USER_ID\" }
  }")

if echo "$BAD_AUTH_RESP" | grep -q "401"; then
  echo -e "${GREEN}✓ Correctly rejected invalid API Key (401)${NC}"
else
  echo -e "${RED}✗ SECURITY FAILURE: Server did not return 401 for bad key!${NC}"
  exit 1
fi
echo ""

# 3b. 正面测试：发送带有正确 API Key 的 Webhook
echo "3b. Sending Polka webhook with VALID API Key..."
WEBHOOK_RESP=$(curl -s -i -X POST "${BASE_URL}/api/polka/webhooks" \
  -H "Content-Type: application/json" \
  -H "Authorization: ApiKey $POLKA_KEY" \
  --data-binary @- << EOF
{
  "event": "user.upgraded",
  "data": {
    "user_id": "$USER_ID"
  }
}
EOF
)

if echo "$WEBHOOK_RESP" | grep -q "204 No Content"; then
  echo -e "${GREEN}✓ Webhook accepted (204 No Content)${NC}"
else
  echo -e "${RED}✗ Webhook failed with valid API Key${NC}"
  echo "Server response:"
  echo "$WEBHOOK_RESP" | head -n 15
  exit 1
fi
echo ""

# 4. 登录以获取最新的 JWT Token
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

# 5. 更新用户（或获取用户信息）验证 is_chirpy_red 是否为 true
echo "5. Verifying user status (is_chirpy_red)..."
UPDATE_RESP=$(curl -s -X PUT "${BASE_URL}/api/users" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{
    "email": "chirpy-red-test@example.com",
    "password": "super-secret-2026"
  }')

if echo "$UPDATE_RESP" | grep -q '"is_chirpy_red":true'; then
  echo -e "${GREEN}✓ SUCCESS: User is now Chirpy Red!${NC}"
else
  echo -e "${RED}✗ Upgrade verification failed!${NC}"
  echo "Response: $UPDATE_RESP"
fi

echo -e "\n${GREEN}Test sequence completed successfully.${NC}"
