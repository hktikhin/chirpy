#!/usr/bin/env bash

set -u

BASE_URL="http://localhost:8080"
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${YELLOW}=== FIXING TEST: CHIRP FILTERING WITH SYNCED IDs ===${NC}"

# 1. 彻底重置并等待 (防止 Race Condition)
echo "1. Resetting database..."
curl -s -X POST "${BASE_URL}/admin/reset" > /dev/null
sleep 0.5

# 2. 创建用户 A 并提取真正的 ID 和 Token
echo "2. Setup User A..."
RESP_A=$(curl -s -X POST "${BASE_URL}/api/users" -H "Content-Type: application/json" -d '{"email":"userA@test.com","password":"password123"}')
ID_A=$(echo "$RESP_A" | grep -oE '"id":"[0-9a-f-]{36}"' | cut -d'"' -f4)

LOGIN_A=$(curl -s -X POST "${BASE_URL}/api/login" -H "Content-Type: application/json" -d '{"email":"userA@test.com","password":"password123"}')
TOKEN_A=$(echo "$LOGIN_A" | grep -oE '"token":"[^"]+"' | cut -d'"' -f4)

if [ -z "$ID_A" ] || [ -z "$TOKEN_A" ]; then
    echo -e "${RED}Error: Could not get ID or Token for User A${NC}"
    exit 1
fi

# 3. 创建用户 B 并提取真正的 ID 和 Token
echo "3. Setup User B..."
RESP_B=$(curl -s -X POST "${BASE_URL}/api/users" -H "Content-Type: application/json" -d '{"email":"userB@test.com","password":"password123"}')
ID_B=$(echo "$RESP_B" | grep -oE '"id":"[0-9a-f-]{36}"' | cut -d'"' -f4)

LOGIN_B=$(curl -s -X POST "${BASE_URL}/api/login" -H "Content-Type: application/json" -d '{"email":"userB@test.com","password":"password123"}')
TOKEN_B=$(echo "$LOGIN_B" | grep -oE '"token":"[^"]+"' | cut -d'"' -f4)

# 4. 发布 Chirps (关键：Body 中不再传 user_id，完全依赖 Token 鉴权)
echo "4. Posting chirps via Authenticated Headers..."

# User A 发 2 条
curl -s -X POST "${BASE_URL}/api/chirps" \
  -H "Authorization: Bearer $TOKEN_A" \
  -H "Content-Type: application/json" \
  -d '{"body":"First one from A"}' > /dev/null

curl -s -X POST "${BASE_URL}/api/chirps" \
  -H "Authorization: Bearer $TOKEN_A" \
  -H "Content-Type: application/json" \
  -d '{"body":"Second one from A"}' > /dev/null

# User B 发 1 条
curl -s -X POST "${BASE_URL}/api/chirps" \
  -H "Authorization: Bearer $TOKEN_B" \
  -H "Content-Type: application/json" \
  -d '{"body":"Hello from B"}' > /dev/null

# 5. 验证过滤逻辑 (?author_id=...)
echo -e "\n5. Validating Filter for User A ($ID_A):"
FILTERED_A=$(curl -s "${BASE_URL}/api/chirps?author_id=$ID_A")
# 统计返回 JSON 中 ID 的数量
COUNT_A=$(echo "$FILTERED_A" | grep -o '"id"' | wc -l)

if [ "$COUNT_A" -eq 2 ]; then
    echo -e "${GREEN}✓ PASS: Found 2 chirps for User A${NC}"
else
    echo -e "${RED}✗ FAIL: Expected 2, but found $COUNT_A${NC}"
    echo "Response: $FILTERED_A"
fi

echo -e "\n6. Validating Global List (No filter):"
COUNT_TOTAL=$(curl -s "${BASE_URL}/api/chirps" | grep -o '"id"' | wc -l)
if [ "$COUNT_TOTAL" -eq 3 ]; then
    echo -e "${GREEN}✓ PASS: Total 3 chirps found${NC}"
else
    echo -e "${RED}✗ FAIL: Expected 3 total, found $COUNT_TOTAL${NC}"
fi
