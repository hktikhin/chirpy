package auth

import (
	"fmt"
	"net/http"
	"strings"
)

func GetAPIKey(headers http.Header) (string, error) {
	authHeader := headers.Get("Authorization")
	if authHeader == "" {
		return "", fmt.Errorf("no authorization header provided")
	}
	const prefix = "ApiKey "
	if !strings.HasPrefix(authHeader, prefix) {
		return "", fmt.Errorf("invalid authorization header format")
	}
	token := strings.TrimPrefix(authHeader, prefix)
	return strings.TrimSpace(token), nil
}
