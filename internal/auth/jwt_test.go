package auth

import (
	"net/http"
	"testing"
	"time"

	"github.com/google/uuid"
)

func TestGetBearerToken(t *testing.T) {
	t.Run("Success: Valid Bearer Token", func(t *testing.T) {
		headers := http.Header{}
		expectedToken := "my-secret-jwt-token"
		headers.Set("Authorization", "Bearer "+expectedToken)

		token, err := GetBearerToken(headers)
		if err != nil {
			t.Fatalf("Expected no error, got %v", err)
		}

		if token != expectedToken {
			t.Errorf("Expected token %s, got %s", expectedToken, token)
		}
	})

	t.Run("Failure: Missing Header", func(t *testing.T) {
		headers := http.Header{} // Empty headers

		_, err := GetBearerToken(headers)
		if err == nil {
			t.Error("Expected error for missing header, but got nil")
		}
	})

	t.Run("Failure: Wrong Prefix", func(t *testing.T) {
		headers := http.Header{}
		headers.Set("Authorization", "ApiKey 12345") // Wrong scheme

		_, err := GetBearerToken(headers)
		if err == nil {
			t.Error("Expected error for non-Bearer prefix, but got nil")
		}
	})

	t.Run("Failure: Only Bearer string", func(t *testing.T) {
		headers := http.Header{}
		headers.Set("Authorization", "Bearer ") // No token after prefix

		token, err := GetBearerToken(headers)
		// Depending on your logic, you might want this to return an error
		// if the resulting string is empty.
		if token == "" && err == nil {
			// Optional: add a check in your function for empty tokens
		}
	})

	t.Run("Success: Extra Whitespace Handling", func(t *testing.T) {
		headers := http.Header{}
		headers.Set("Authorization", "Bearer  token-with-spaces-around  ")

		token, err := GetBearerToken(headers)
		if err != nil {
			t.Fatalf("Expected no error, got %v", err)
		}

		if token != "token-with-spaces-around" {
			t.Errorf("Expected trimmed token, got '%s'", token)
		}
	})
}

func TestJWT(t *testing.T) {
	secret := "my-ultra-secret-key-123"
	userID := uuid.New()

	// 1. Test Success Case
	t.Run("Valid Token", func(t *testing.T) {
		tokenStr, err := MakeJWT(userID, secret, time.Hour)
		if err != nil {
			t.Fatalf("Expected no error, got %v", err)
		}

		parsedID, err := ValidateJWT(tokenStr, secret)
		if err != nil {
			t.Fatalf("Validation failed: %v", err)
		}

		if parsedID != userID {
			t.Errorf("Expected UUID %v, got %v", userID, parsedID)
		}
	})

	// 2. Test Expiration Case
	t.Run("Expired Token", func(t *testing.T) {
		// Create a token that expired 1 hour ago
		tokenStr, _ := MakeJWT(userID, secret, -time.Hour)

		_, err := ValidateJWT(tokenStr, secret)
		if err == nil {
			t.Error("Expected error for expired token, but got nil")
		}
	})

	// 3. Test Wrong Secret (Signature Mismatch)
	t.Run("Wrong Secret", func(t *testing.T) {
		tokenStr, _ := MakeJWT(userID, secret, time.Hour)

		_, err := ValidateJWT(tokenStr, "the-wrong-password")
		if err == nil {
			t.Error("Expected error due to signature mismatch, but got nil")
		}
	})

	// 4. Test Malformed Token
	t.Run("Malformed Token", func(t *testing.T) {
		_, err := ValidateJWT("not-a-real-jwt-string", secret)
		if err == nil {
			t.Error("Expected error for malformed token string")
		}
	})
}
