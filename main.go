package main

import (
	"database/sql"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"strings"
	"sync/atomic"
	"time"

	"github.com/google/uuid"
	"github.com/hktikhin/chirpy/internal/auth"
	"github.com/hktikhin/chirpy/internal/database"
	_ "github.com/lib/pq"

	"github.com/joho/godotenv"
)

type apiConfig struct {
	fileserverHits atomic.Int32
	db             *database.Queries
	platform       string
	tokenSecret    string
}

type User struct {
	ID        uuid.UUID `json:"id"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
	Email     string    `json:"email"`
}

type Chirp struct {
	ID        uuid.UUID `json:"id"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
	Body      string    `json:"body"`
	UserID    uuid.UUID `json:"user_id"`
}

func databaseChirpToChirp(dbChirp database.Chirp) Chirp {
	return Chirp{
		ID:        dbChirp.ID,
		CreatedAt: dbChirp.CreatedAt,
		UpdatedAt: dbChirp.UpdatedAt,
		Body:      dbChirp.Body,
		UserID:    dbChirp.UserID,
	}
}

func databaseCreateUserRowToUser(row database.CreateUserRow) User {
	return User{
		ID:        row.ID,
		CreatedAt: row.CreatedAt,
		UpdatedAt: row.UpdatedAt,
		Email:     row.Email,
	}
}

func databaseUserToUser(dbUser database.User) User {
	return User{
		ID:        dbUser.ID,
		CreatedAt: dbUser.CreatedAt,
		UpdatedAt: dbUser.UpdatedAt,
		Email:     dbUser.Email,
	}
}

func databaseUpdateUserRowToUser(row database.UpdateUserRow) User {
	return User{
		ID:        row.ID,
		CreatedAt: row.CreatedAt,
		UpdatedAt: row.UpdatedAt,
		Email:     row.Email,
	}
}

func (cfg *apiConfig) middlewareMetricsInc(next http.Handler) http.Handler {
	return http.HandlerFunc(
		func(w http.ResponseWriter, r *http.Request) {
			cfg.fileserverHits.Add(1)
			next.ServeHTTP(w, r)
		},
	)
}

func (cfg *apiConfig) handlerMetrics(w http.ResponseWriter, r *http.Request) {
	const template = `
<html>
  <body>
    <h1>Welcome, Chirpy Admin</h1>
    <p>Chirpy has been visited %d times!</p>
  </body>
</html>
`
	w.Header().Add("Content-Type", "text/html; charset=utf-8")
	w.WriteHeader(200)
	w.Write([]byte(fmt.Sprintf(template, cfg.fileserverHits.Load())))
}

func (cfg *apiConfig) handlerReset(w http.ResponseWriter, r *http.Request) {
	if cfg.platform != "dev" {
		respondWithError(w, 403, "403 Forbidden")
	}
	err := cfg.db.DeleteAllUsers(r.Context())
	if err != nil {
		log.Printf("Error resetting users table: %s", err)
		respondWithError(w, 400, "Error resetting users table")
		return
	}
	w.Header().Add("Content-Type", "text/plain; charset=utf-8")
	w.WriteHeader(200)
	cfg.fileserverHits.Store(0)
}

func handlerHealthz(w http.ResponseWriter, r *http.Request) {
	w.Header().Add("Content-Type", "text/plain; charset=utf-8")
	w.WriteHeader(200)
	w.Write([]byte("OK"))
}

func respondWithError(w http.ResponseWriter, code int, msg string) {
	type errorRes struct {
		Error string `json:"error"`
	}
	respondWithJSON(w, code, errorRes{
		Error: msg,
	})
}

func respondWithJSON(w http.ResponseWriter, code int, payload interface{}) {
	dat, err := json.Marshal(payload)
	if err != nil {
		log.Printf("Error marshalling JSON: %s", err)
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(500)
		return
	}
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(code)
	w.Write(dat)
}

func getCleanedBody(body string) string {
	badWords := map[string]struct{}{
		"kerfuffle": {},
		"sharbert":  {},
		"fornax":    {},
	}

	words := strings.Split(body, " ")
	for i, word := range words {
		loweredWord := strings.ToLower(word)
		if _, ok := badWords[loweredWord]; ok {
			words[i] = "****"
		}
	}
	return strings.Join(words, " ")
}

func (cfg *apiConfig) handlerCreateChirp(w http.ResponseWriter, r *http.Request) {
	type parameters struct {
		Body   string    `json:"body"`
		UserID uuid.UUID `json:"user_id"`
	}
	signedToken, err := auth.GetBearerToken(r.Header)
	if err != nil {
		log.Printf("Error extracting api token: %s", err)
		respondWithError(w, 401, fmt.Sprintf("Error extracting api token: %s", err))
		return
	}
	_, err = auth.ValidateJWT(signedToken, cfg.tokenSecret)
	if err != nil {
		log.Printf("Fail to validate api token: %s", err)
		respondWithError(w, 401, "Fail to validate api token")
		return
	}

	decoder := json.NewDecoder(r.Body)
	params := parameters{}
	err = decoder.Decode(&params)
	if err != nil {
		log.Printf("Error decoding parameters: %s", err)
		respondWithError(w, 400, "Invalid JSON")
		return
	}
	if len(params.Body) > 140 {
		respondWithError(w, 400, "Chirp is too long")
		return
	}
	dbChirp, err := cfg.db.CreateChirp(
		r.Context(),
		database.CreateChirpParams{
			Body:   getCleanedBody(params.Body),
			UserID: params.UserID,
		},
	)
	if err != nil {
		log.Printf("Error creating chirp: %s", err)
		respondWithError(w, 400, "Error creating chirp")
		return
	}
	respondWithJSON(w, 201, databaseChirpToChirp(dbChirp))
}

func (cfg *apiConfig) handlerGetChirps(w http.ResponseWriter, r *http.Request) {
	dbChirps, err := cfg.db.GetAllChirps(
		r.Context(),
	)
	if err != nil {
		log.Printf("Could not get chirps: %s", err)
		respondWithError(w, 500, "Could not get chirps")
		return
	}
	chirps := []Chirp{}
	for _, dbChirp := range dbChirps {
		chirps = append(chirps, databaseChirpToChirp(dbChirp))
	}

	respondWithJSON(w, 200, chirps)
}

func (cfg *apiConfig) handlerGetChirpByID(w http.ResponseWriter, r *http.Request) {
	rawID := r.PathValue("chirpID")
	chirpID, err := uuid.Parse(rawID)
	if err != nil {
		respondWithError(w, 400, "Invalid chirp ID format")
		return
	}

	dbChirp, err := cfg.db.GetChirpByID(
		r.Context(),
		chirpID,
	)
	if err != nil {
		log.Printf("Chirp with that id not found: %s", err)
		respondWithError(w, 404, "Chirp with that id not found")
		return
	}

	respondWithJSON(w, 200, databaseChirpToChirp(dbChirp))
}

func (cfg *apiConfig) handlerCreateUser(w http.ResponseWriter, r *http.Request) {
	type parameters struct {
		Email    string `json:"email"`
		Password string `json:"password"`
	}

	decoder := json.NewDecoder(r.Body)
	params := parameters{}
	err := decoder.Decode(&params)
	if err != nil {
		log.Printf("Error decoding parameters: %s", err)
		respondWithError(w, 400, "Invalid JSON")
		return
	}
	hashPassword, err := auth.HashPassword(params.Password)
	if err != nil {
		respondWithError(w, 500, "Couldn't hash password")
		return
	}
	dbUser, err := cfg.db.CreateUser(r.Context(), database.CreateUserParams{
		Email:          params.Email,
		HashedPassword: hashPassword,
	})
	if err != nil {
		log.Printf("Error creating user: %s", err)
		respondWithError(w, 400, "Error creating user")
		return
	}

	respondWithJSON(w, 201, databaseCreateUserRowToUser(dbUser))
}

func (cfg *apiConfig) handlerLogin(w http.ResponseWriter, r *http.Request) {
	type parameters struct {
		Email    string `json:"email"`
		Password string `json:"password"`
	}
	decoder := json.NewDecoder(r.Body)
	params := parameters{}
	err := decoder.Decode(&params)
	if err != nil {
		log.Printf("Error decoding parameters: %s", err)
		respondWithError(w, 400, "Invalid JSON")
		return
	}

	dbUser, err := cfg.db.GetUserByEmail(r.Context(), params.Email)
	if err != nil {
		log.Printf("Error getting user record: %s", err)
		respondWithError(w, 401, "Error getting user record")
		return
	}
	match, err := auth.CheckPasswordHash(params.Password, dbUser.HashedPassword)
	if !match || err != nil {
		log.Printf("Password Mismatch")
		respondWithError(w, 401, "Password Mismatch")
		return
	}
	accessToken, err := auth.MakeJWT(dbUser.ID, cfg.tokenSecret, time.Duration(3600)*time.Second)
	if err != nil {
		log.Printf("Error generating jwt token: %s", err)
		respondWithError(w, 401, "Error generating jwt token")
		return
	}

	refreshToken := auth.MakeRefreshToken()
	err = cfg.db.CreateRefreshToken(
		r.Context(),
		database.CreateRefreshTokenParams{
			Token:     refreshToken,
			UserID:    dbUser.ID,
			ExpiresAt: time.Now().Add(time.Hour * 24 * 60),
		},
	)
	if err != nil {
		log.Printf("Error storing refresh token: %s", err)
		respondWithError(w, 401, "Error storing refrsh token")
		return
	}

	respondWithJSON(w, 200, struct {
		User
		Token        string `json:"token"`
		RefreshToken string `json:"refresh_token"`
	}{
		User:         databaseUserToUser(dbUser),
		Token:        accessToken,
		RefreshToken: refreshToken,
	})
}

func (cfg *apiConfig) handlerRefresh(w http.ResponseWriter, r *http.Request) {
	refreshToken, err := auth.GetBearerToken(r.Header)
	if err != nil {
		log.Printf("Error extracting refresh token: %s", err)
		respondWithError(w, 401, fmt.Sprintf("Error extracting refresh token: %s", err))
		return
	}
	dbRefreshToken, err := cfg.db.GetUserFromRefreshToken(r.Context(), refreshToken)
	if err != nil {
		log.Printf("Refresh token not existed: %s", err)
		respondWithError(w, 401, "Refresh token not existed")
		return
	}
	if dbRefreshToken.ExpiresAt.Before(time.Now()) || dbRefreshToken.RevokedAt.Valid {
		log.Printf("Invalid refresh token")
		respondWithError(w, 401, "Invalid refresh token")
		return
	}
	accessToken, err := auth.MakeJWT(dbRefreshToken.UserID, cfg.tokenSecret, time.Duration(3600)*time.Second)
	if err != nil {
		log.Printf("Error generating jwt token: %s", err)
		respondWithError(w, 401, "Error generating jwt token")
		return
	}
	respondWithJSON(w, 200, struct {
		Token string `json:"token"`
	}{
		Token: accessToken,
	})
}

func (cfg *apiConfig) handlerRevoke(w http.ResponseWriter, r *http.Request) {
	refreshToken, err := auth.GetBearerToken(r.Header)
	if err != nil {
		log.Printf("Error extracting refresh token: %s", err)
		respondWithError(w, 401, fmt.Sprintf("Error extracting refresh token: %s", err))
		return
	}
	rowsAffected, err := cfg.db.RevokeRefreshToken(r.Context(), refreshToken)
	if rowsAffected == 0 {
		log.Printf("Active refresh token not existed.")
		respondWithError(w, 401, "Active refresh token not existed.")
		return
	}
	if err != nil {
		log.Printf("Error revoking refresh token: %s", err)
		respondWithError(w, 401, "Error revoking refresh token")
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (cfg *apiConfig) handlerUpdateUser(w http.ResponseWriter, r *http.Request) {
	type parameters struct {
		Email    string `json:"email"`
		Password string `json:"password"`
	}

	signedToken, err := auth.GetBearerToken(r.Header)
	if err != nil {
		log.Printf("Error extracting api token: %s", err)
		respondWithError(w, 401, fmt.Sprintf("Error extracting api token: %s", err))
		return
	}
	userID, err := auth.ValidateJWT(signedToken, cfg.tokenSecret)
	if err != nil {
		log.Printf("Fail to validate api token: %s", err)
		respondWithError(w, 401, "Fail to validate api token")
		return
	}

	decoder := json.NewDecoder(r.Body)
	params := parameters{}
	err = decoder.Decode(&params)
	if err != nil {
		log.Printf("Error decoding parameters: %s", err)
		respondWithError(w, 400, "Invalid JSON")
		return
	}
	hashPassword, err := auth.HashPassword(params.Password)
	if err != nil {
		respondWithError(w, 500, "Couldn't hash password")
		return
	}
	dbUser, err := cfg.db.UpdateUser(r.Context(), database.UpdateUserParams{
		ID:             userID,
		Email:          params.Email,
		HashedPassword: hashPassword,
	})
	if err != nil {
		log.Printf("Error updating user: %s", err)
		respondWithError(w, 400, "Error updating user")
		return
	}

	respondWithJSON(w, 200, databaseUpdateUserRowToUser(dbUser))
}

func main() {
	godotenv.Load()

	dbURL := os.Getenv("DB_URL")
	platform := os.Getenv("PLATFORM")
	tokenSecret := os.Getenv("TOKEN_SECRET")
	db, err := sql.Open("postgres", dbURL)
	if err != nil {
		fmt.Printf("Error: %v", err)
		os.Exit(1)
	}
	dbQueries := database.New(db)

	mux := http.NewServeMux()
	apiCfg := &apiConfig{db: dbQueries, platform: platform, tokenSecret: tokenSecret}

	fsHandler := http.StripPrefix("/app/", http.FileServer(http.Dir(".")))
	mux.Handle("/app/", apiCfg.middlewareMetricsInc(fsHandler))

	mux.HandleFunc("GET /api/healthz", handlerHealthz)

	mux.HandleFunc("GET /api/chirps", apiCfg.handlerGetChirps)

	mux.HandleFunc("GET /api/chirps/{chirpID}", apiCfg.handlerGetChirpByID)

	mux.HandleFunc("POST /api/chirps", apiCfg.handlerCreateChirp)

	mux.HandleFunc("POST /api/users", apiCfg.handlerCreateUser)

	mux.HandleFunc("POST /api/login", apiCfg.handlerLogin)

	mux.HandleFunc("POST /api/refresh", apiCfg.handlerRefresh)

	mux.HandleFunc("POST /api/revoke", apiCfg.handlerRevoke)

	mux.HandleFunc("PUT /api/users", apiCfg.handlerUpdateUser)

	mux.HandleFunc("GET /admin/metrics", apiCfg.handlerMetrics)

	mux.HandleFunc("POST /admin/reset", apiCfg.handlerReset)

	server := &http.Server{
		Addr:    ":8080",
		Handler: mux,
	}
	server.ListenAndServe()
}
