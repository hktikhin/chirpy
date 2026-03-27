package auth

import (
	"net/http"
	"testing"
)

func TestGetAPIKey(t *testing.T) {
	// 1. Define the test case structure
	tests := []struct {
		name          string
		headers       http.Header
		expectedToken string
		wantErr       bool
	}{
		{
			name:          "Valid API Key",
			headers:       http.Header{"Authorization": []string{"ApiKey secret-123"}},
			expectedToken: "secret-123",
			wantErr:       false,
		},
		{
			name:          "Valid API Key with extra spaces",
			headers:       http.Header{"Authorization": []string{"ApiKey   trimmed-token   "}},
			expectedToken: "trimmed-token",
			wantErr:       false,
		},
		{
			name:          "Missing Authorization Header",
			headers:       http.Header{},
			expectedToken: "",
			wantErr:       true,
		},
		{
			name:          "Malformed Header (No Prefix)",
			headers:       http.Header{"Authorization": []string{"wrong-prefix 123"}},
			expectedToken: "",
			wantErr:       true,
		},
		{
			name:          "Malformed Header (Wrong Prefix)",
			headers:       http.Header{"Authorization": []string{"Bearer some-token"}},
			expectedToken: "",
			wantErr:       true,
		},
		{
			name:          "Case Sensitivity Check (apikey instead of ApiKey)",
			headers:       http.Header{"Authorization": []string{"apikey lowercase-prefix"}},
			expectedToken: "",
			wantErr:       true,
		},
	}

	// 2. Iterate through cases using subtests
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got, err := GetAPIKey(tt.headers)

			// 3. Assert error state
			if (err != nil) != tt.wantErr {
				t.Fatalf("GetAPIKey() error = %v, wantErr %v", err, tt.wantErr)
			}

			// 4. Assert result
			if got != tt.expectedToken {
				t.Errorf("GetAPIKey() got = %v, want %v", got, tt.expectedToken)
			}
		})
	}
}
