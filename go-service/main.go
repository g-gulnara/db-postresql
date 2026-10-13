
package main

import (
	"context"
	"encoding/json"
	"errors"
	"log"
	"net"
	"net/http"
	"net/url"
	"os"
	"strconv"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
)

type App struct {
	db *pgxpool.Pool
}

type ErrorResponse struct {
	Error string `json:"error"`
}

type HealthResponse struct {
	Status string `json:"status"`
}

type FineStatsResponse struct {
	TotalFines  int64   `json:"total_fines"`
	UnpaidFines int64   `json:"unpaid_fines"`
	UnpaidAmount float64 `json:"unpaid_amount"`
}

func main() {
	db, err := ConnectToDatabase()
	if err != nil {
		log.Fatalf("failed to connect to database: %v", err)
	}
	defer db.Close()

	app := &App{db: db}

	mux := http.NewServeMux()
	mux.HandleFunc("/health", app.HealthHandler)
	mux.HandleFunc("/ready", app.ReadyHandler)
	mux.HandleFunc("/api/v1/stats/fines", app.FineStatsHandler)

	port := os.Getenv("HTTP_PORT")
	if port == "" {
		port = "8080"
	}

	server := &http.Server{
		Addr:              ":" + port,
		Handler:           mux,
		ReadHeaderTimeout: 5 * time.Second,
	}

	log.Printf("Go service is listening on port %s", port)

	if err := server.ListenAndServe(); err != nil &&
		!errors.Is(err, http.ErrServerClosed) {
		log.Fatalf("HTTP server failed: %v", err)
	}
}

func ConnectToDatabase() (*pgxpool.Pool, error) {
	host := envOrDefault("POSTGRES_HOST", "localhost")
	port := envOrDefault("POSTGRES_PORT", "5432")
	user := os.Getenv("POSTGRES_USER")
	password := os.Getenv("POSTGRES_PASSWORD")
	database := os.Getenv("POSTGRES_DB")

	if user == "" || database == "" {
		return nil, errors.New(
			"POSTGRES_USER and POSTGRES_DB must be set",
		)
	}

	portNumber, err := strconv.Atoi(port)
	if err != nil || portNumber < 1 || portNumber > 65535 {
		return nil, errors.New("POSTGRES_PORT must be a valid port")
	}

	databaseURL := url.URL{
		Scheme: "postgres",
		User:   url.UserPassword(user, password),
		Host:   net.JoinHostPort(host, port),
		Path:   database,
	}

	query := databaseURL.Query()
	query.Set("sslmode", "disable")
	databaseURL.RawQuery = query.Encode()

	config, err := pgxpool.ParseConfig(databaseURL.String())
	if err != nil {
		return nil, err
	}

	config.MaxConns = 5
	config.MinConns = 1

	db, err := pgxpool.NewWithConfig(context.Background(), config)
	if err != nil {
		return nil, err
	}

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	if err := db.Ping(ctx); err != nil {
		db.Close()
		return nil, err
	}

	return db, nil
}

func (app *App) HealthHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		writeError(w, http.StatusMethodNotAllowed, "method not allowed")
		return
	}

	writeJSON(w, http.StatusOK, HealthResponse{Status: "ok"})
}

func (app *App) ReadyHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		writeError(w, http.StatusMethodNotAllowed, "method not allowed")
		return
	}

	ctx, cancel := context.WithTimeout(r.Context(), 3*time.Second)
	defer cancel()

	if err := app.db.Ping(ctx); err != nil {
		writeError(w, http.StatusServiceUnavailable, "database unavailable")
		return
	}

	writeJSON(w, http.StatusOK, HealthResponse{Status: "ready"})
}

func (app *App) FineStatsHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		writeError(w, http.StatusMethodNotAllowed, "method not allowed")
		return
	}

	ctx, cancel := context.WithTimeout(r.Context(), 5*time.Second)
	defer cancel()

	var stats FineStatsResponse

	err := app.db.QueryRow(ctx, `
		SELECT
			COUNT(*),
			COUNT(*) FILTER (WHERE payment_status IS NOT TRUE),
			COALESCE(
				SUM(amount) FILTER (WHERE payment_status IS NOT TRUE),
				0
			)
		FROM fines
	`).Scan(
		&stats.TotalFines,
		&stats.UnpaidFines,
		&stats.UnpaidAmount,
	)
	if err != nil {
		log.Printf("failed to get fine statistics: %v", err)
		writeError(w, http.StatusInternalServerError, "failed to get statistics")
		return
	}

	writeJSON(w, http.StatusOK, stats)
}

func writeJSON(w http.ResponseWriter, status int, value any) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.WriteHeader(status)

	if err := json.NewEncoder(w).Encode(value); err != nil {
		log.Printf("failed to encode JSON response: %v", err)
	}
}

func writeError(w http.ResponseWriter, status int, message string) {
	writeJSON(w, status, ErrorResponse{Error: message})
}

func envOrDefault(key, fallback string) string {
	value := os.Getenv(key)
	if value == "" {
		return fallback
	}
	return value
}
