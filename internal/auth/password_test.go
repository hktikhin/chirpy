package auth

import (
	"testing"
)

func TestHashPassword(t *testing.T) {
	password := "my-secret-password"

	// Test 1: Successful hashing
	hash1, err := HashPassword(password)
	if err != nil {
		t.Fatalf("Expected no error when hashing, got %v", err)
	}

	if hash1 == "" {
		t.Fatal("Expected hash string to be non-empty")
	}

	// Test 2: Salt uniqueness
	// Hashing the same password twice should yield different results
	hash2, err := HashPassword(password)
	if err != nil {
		t.Fatalf("Expected no error when hashing second time, got %v", err)
	}

	if hash1 == hash2 {
		t.Errorf("Expected different hashes for same password due to random salt, but they were identical")
	}
}

func TestCheckPasswordHash(t *testing.T) {
	password := "super-secure-123"
	wrongPassword := "wrong-pass"

	hash, err := HashPassword(password)
	if err != nil {
		t.Fatalf("Failed to create hash for testing: %v", err)
	}

	// Case 1: Correct password matches
	match, err := CheckPasswordHash(password, hash)
	if err != nil {
		t.Errorf("Error during password check: %v", err)
	}
	if !match {
		t.Errorf("Expected password to match hash, but it failed")
	}

	// Case 2: Wrong password does not match
	match, err = CheckPasswordHash(wrongPassword, hash)
	if err != nil {
		t.Errorf("Error during wrong password check: %v", err)
	}
	if match {
		t.Errorf("Expected wrong password to NOT match hash, but it did")
	}
}
