#!/bin/bash

# 定义基础 URL
BASE_URL="http://localhost:8080"

echo "--- 1. Testing Healthz ---"
curl -i $BASE_URL/api/healthz
echo -e "\n"

echo "--- 2. Testing Metrics (Admin) ---"
curl -i $BASE_URL/admin/metrics
echo -e "\n"

echo "--- 3. Testing Validate Chirp (Valid) ---"
curl -i -X POST $BASE_URL/api/validate_chirp \
     -H "Content-Type: application/json" \
     -d '{"body": "Hello Chirpy!"}'
echo -e "\n"

echo "--- 4. Testing Validate Chirp (Too Long) ---"
# 生成超过 255 字符的字符串
LONG_BODY=$(printf 'a%.0s' {1..260})
curl -i -X POST $BASE_URL/api/validate_chirp \
     -H "Content-Type: application/json" \
     -d "{\"body\": \"$LONG_BODY\"}"
echo -e "\n"

echo "--- 5. Testing Reset (Admin) ---"
curl -i -X POST $BASE_URL/admin/reset
echo -e "\n"

echo "--- 6. Re-checking Metrics after Reset ---"
curl -i $BASE_URL/admin/metrics
echo -e "\n"

echo "--- 7. Testing Profanity Filter (kerfuffle, sharbert, fornax) ---"
# 测试包含混合大小写和脏词的句子
curl -i -X POST $BASE_URL/api/validate_chirp \
     -H "Content-Type: application/json" \
     -d '{"body": "I had a Kerfuffle while eating sharbert in Fornax"}'
echo -e "\n"

echo "--- 8. Testing Profanity Filter (Normal Text) ---"
# 测试正常句子，确保不会误伤
curl -i -X POST $BASE_URL/api/validate_chirp \
     -H "Content-Type: application/json" \
     -d '{"body": "This is a clean and nice chirp"}'
echo -e "\n"