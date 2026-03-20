-- name: CreateRefreshToken :exec
INSERT INTO refresh_tokens (token,user_id,expires_at)
VALUES (
    $1,
    $2,
    $3
);

-- name: GetUserFromRefreshToken :one
SELECT 
    token,user_id,expires_at,revoked_at
FROM refresh_tokens
WHERE token = $1
;

-- name: RevokeRefreshToken :execrows
UPDATE refresh_tokens
SET 
    revoked_at = NOW(),
    updated_at = NOW()
WHERE token = $1 
  AND revoked_at IS NULL
;