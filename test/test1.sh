#!/bin/bash

# ────────────────────────────────────────────────
#     Chirpy API Tests – Clean Start (2026 edition)
# ────────────────────────────────────────────────

BASE_URL="http://localhost:8080"

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

echo "=== Chirpy API Tests ==="
echo "Started: $(date)"
echo ""

# 1–2: Basic health & metrics
echo "1. Health check"
curl -s -i "$BASE_URL/api/healthz" | head -n 1
echo ""

echo "2. Admin metrics (at start)"
curl -s -i "$BASE_URL/admin/metrics" | grep -E "HTTP/|Content-Length|<p>"
echo ""

# 3: Reset DB → clean state
echo "3. Reset database (delete all users) – expect 200 in dev"
RESET_RESP=$(curl -s -i -X POST "$BASE_URL/admin/reset")
echo "$RESET_RESP" | head -n 1
echo ""

# 4: Metrics after reset
echo "4. Metrics right after reset"
curl -s -i "$BASE_URL/admin/metrics" | grep -E "HTTP/|Content-Length|<p>"
echo ""

# ─── Users ───────────────────────────────────────
echo "5. Create user – Alice"
ALICE_RESP=$(curl -s -X POST "$BASE_URL/api/users" \
     -H "Content-Type: application/json" \
     -d '{"email": "alice@example.com"}')

echo "$ALICE_RESP" | head -n 6   # show status + first lines of body
echo ""

echo "6. Create user – Bob"
BOB_RESP=$(curl -s -X POST "$BASE_URL/api/users" \
     -H "Content-Type: application/json" \
     -d '{"email": "bob@testing.dev"}')

echo "$BOB_RESP" | head -n 6
echo ""

echo "7. Create user – invalid JSON → should 400"
curl -s -i -X POST "$BASE_URL/api/users" \
     -H "Content-Type: application/json" \
     -d '{email: "broken"}' | head -n 3
echo ""

# ─── Extract real user ID (try Alice first, fallback to Bob) ──────────────
USER_ID=$(echo "$ALICE_RESP" | grep -oE '"id":"[0-9a-f-]{36}"' | head -1 | cut -d'"' -f4)

if [ -z "$USER_ID" ]; then
  USER_ID=$(echo "$BOB_RESP" | grep -oE '"id":"[0-9a-f-]{36}"' | head -1 | cut -d'"' -f4)
fi

if [ -z "$USER_ID" ]; then
  echo -e "${RED}ERROR: Could not extract any valid user ID${NC}"
  echo "Alice response snippet:"
  echo "$ALICE_RESP" | head -n 8
  echo "→ Check if POST /api/users returns 201 + {\"id\": …}"
  exit 1
fi

echo -e "${GREEN}Using real user ID:${NC} $USER_ID"
echo ""

# ─── Chirp creation tests ────────────────────────────────────────────────
echo "11. Create chirp – valid"
curl -i -X POST "$BASE_URL/api/chirps" \
     -H "Content-Type: application/json" \
     -d '{
           "body": "This is my first chirp :chirpy:",
           "user_id": "'"$USER_ID"'"
         }' | head -n 8
echo ""

echo "12. Create chirp – profanity should be cleaned"
curl -i -X POST "$BASE_URL/api/chirps" \
     -H "Content-Type: application/json" \
     -d '{
           "body": "What a kerfuffle sharbert fornax day!",
           "user_id": "'"$USER_ID"'"
         }' | head -n 8
echo ""

echo "13. Create chirp – too long → should 400"
LONG_BODY=$(printf 'z%.0s' {1..300})
curl -i -X POST "$BASE_URL/api/chirps" \
     -H "Content-Type: application/json" \
     -d '{
           "body": "'"$LONG_BODY"'",
           "user_id": "'"$USER_ID"'"
         }'
echo ""

echo "14. Create chirp – missing user_id → should fail"
curl -i -X POST "$BASE_URL/api/chirps" \
     -H "Content-Type: application/json" \
     -d '{"body": "No user id here"}'
echo ""

echo "15. Create chirp – invalid uuid format → should fail"
curl -i -X POST "$BASE_URL/api/chirps" \
     -H "Content-Type: application/json" \
     -d '{
           "body": "Bad uuid test",
           "user_id": "not-a-uuid"
         }' 
         
echo ""

echo -e "${GREEN}Tests finished.${NC}\n"
echo "Quick status:"
echo "  • If chirp creation still fails with foreign key → user creation is broken"
echo "  • If 404 on /api/chirps → check mux.HandleFunc(\"POST /api/chirps\", …)"
echo "  • If 404 on /api/users → same, check route registration (no trailing space!)"
echo ""