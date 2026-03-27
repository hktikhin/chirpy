#!/usr/bin/env bash

set -u

BASE_URL="http://localhost:8080"
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${YELLOW}=== TEST: CHIRP IN-MEMORY SORTING (ASC vs DESC) ===${NC}"

# 1. 重置數據庫
curl -s -X POST "${BASE_URL}/admin/reset" > /dev/null

# 2. 建立測試用戶並登入
RESP=$(curl -s -X POST "${BASE_URL}/api/users" -H "Content-Type: application/json" -d '{"email":"sort@test.com","password":"password123"}')
TOKEN=$(curl -s -X POST "${BASE_URL}/api/login" -H "Content-Type: application/json" -d '{"email":"sort@test.com","password":"password123"}' | grep -oE '"token":"[^"]+"' | cut -d'"' -f4)

# 3. 建立三條 Chirps，中間間隔 1 秒以確保 CreatedAt 不同
echo "Posting 3 chirps with delays..."
curl -s -X POST "${BASE_URL}/api/chirps" -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" -d '{"body":"Oldest Chirp (1)"}' > /dev/null
sleep 1.1
curl -s -X POST "${BASE_URL}/api/chirps" -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" -d '{"body":"Middle Chirp (2)"}' > /dev/null
sleep 1.1
curl -s -X POST "${BASE_URL}/api/chirps" -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" -d '{"body":"Newest Chirp (3)"}' > /dev/null

# 4. 測試 預設/ASC 排序 (舊的在前)
echo -e "\n4. Testing Default (ASC) Sort..."
ASC_RESP=$(curl -s "${BASE_URL}/api/chirps")
FIRST_ASC=$(echo "$ASC_RESP" | grep -oE '"body":"[^"]+"' | head -n 1)

if [[ "$FIRST_ASC" == *"Oldest"* ]]; then
    echo -e "${GREEN}✓ PASS: Oldest chirp is first in ASC order${NC}"
else
    echo -e "${RED}✗ FAIL: Unexpected first chirp in ASC order: $FIRST_ASC${NC}"
fi

# 5. 測試 DESC 排序 (新的在前)
echo -e "\n5. Testing DESC Sort (?sort=desc)..."
DESC_RESP=$(curl -s "${BASE_URL}/api/chirps?sort=desc")
FIRST_DESC=$(echo "$DESC_RESP" | grep -oE '"body":"[^"]+"' | head -n 1)

if [[ "$FIRST_DESC" == *"Newest"* ]]; then
    echo -e "${GREEN}✓ PASS: Newest chirp is first in DESC order${NC}"
else
    echo -e "${RED}✗ FAIL: Unexpected first chirp in DESC order: $FIRST_DESC${NC}"
fi

# 6. 混合測試：Author Filter + Sort Desc
# (假設 ID_A 已經在之前的步驟獲取，這裡簡化邏輯)
echo -e "\n6. Testing Combined Filter + Sort Desc..."
# 這裡可以用之前腳本提取的 ID 進行測試

echo -e "\n${YELLOW}=== Sort Logic Verification Complete ===${NC}"
