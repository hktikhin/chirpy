#!/bin/bash

# ────────────────────────────────────────────────
#          Chirpy API Tests – Clean Start
# ────────────────────────────────────────────────

BASE_URL="http://localhost:8080"

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

echo "=== Chirpy API Tests ==="
echo "Started: $(date)"
echo ""

echo "1. Health check"
curl -s -i "$BASE_URL/api/healthz" | head -n 1
echo ""

echo "2. Admin metrics (very start)"
curl -s -i "$BASE_URL/admin/metrics" | grep -E "HTTP/|Content-Length"
echo ""

# ─── Reset early so every run starts clean ───────────────────────────────
echo "3. Reset database (delete all users) – expect 200 when PLATFORM=dev"
curl -i -X POST "$BASE_URL/admin/reset"
echo ""

echo "4. Metrics right after reset (fileserverHits should be reset to 0)"
curl -i "$BASE_URL/admin/metrics"
echo ""

# ─── Now safe to create users ────────────────────────────────────────────
echo "5. Create user – Alice"
curl -i -X POST "$BASE_URL/api/users" \
     -H "Content-Type: application/json" \
     -d '{"email": "alice@example.com"}'
echo ""

echo "6. Create user – Bob"
curl -i -X POST "$BASE_URL/api/users" \
     -H "Content-Type: application/json" \
     -d '{"email": "bob@testing.dev"}'
echo ""

echo "7. Try invalid JSON → should be 400"
curl -i -X POST "$BASE_URL/api/users" \
     -H "Content-Type: application/json" \
     -d '{email: "broken"}'
echo ""

# ─── Chirp validation & profanity ────────────────────────────────────────
echo "8. Validate chirp – normal"
curl -i -X POST "$BASE_URL/api/validate_chirp" \
     -H "Content-Type: application/json" \
     -d '{"body": "Hello beautiful world!"}'
echo ""

echo "9. Validate chirp – way too long"
LONG=$(printf 'z%.0s' {1..300})
curl -i -X POST "$BASE_URL/api/validate_chirp" \
     -H "Content-Type: application/json" \
     -d "{\"body\": \"$LONG\"}"
echo ""

echo "10. Profanity filter test"
curl -i -X POST "$BASE_URL/api/validate_chirp" \
     -H "Content-Type: application/json" \
     -d '{"body": "What a Kerfuffle sharbert Fornax moment!"}'
echo ""

echo -e "${GREEN}All tests finished.${NC}\n"

echo "Quick reminders:"
echo "  • Make sure PLATFORM=dev is set in .env"
echo "  • sqlc generate was run after adding DeleteAllUsers"
echo "  • No trailing space in mux.HandleFunc(\"POST /api/users\", ...)"
echo ""