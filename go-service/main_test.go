
package main

import (
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestHealthHandler(t *testing.T) {
	app := &App{}

	request := httptest.NewRequest(http.MethodGet, "/health", nil)
	response := httptest.NewRecorder()

	app.HealthHandler(response, request)

	if response.Code != http.StatusOK {
		t.Fatalf("expected status %d, got %d",
			http.StatusOK, response.Code)
	}

	if contentType := response.Header().Get("Content-Type"); contentType != "application/json; charset=utf-8" {
		t.Fatalf("unexpected Content-Type: %s", contentType)
	}

	if response.Body.String() != "{\"status\":\"ok\"}\n" {
		t.Fatalf("unexpected response body: %s", response.Body.String())
	}
}

func TestHealthHandlerRejectsPost(t *testing.T) {
	app := &App{}

	request := httptest.NewRequest(http.MethodPost, "/health", nil)
	response := httptest.NewRecorder()

	app.HealthHandler(response, request)

	if response.Code != http.StatusMethodNotAllowed {
		t.Fatalf("expected status %d, got %d",
			http.StatusMethodNotAllowed, response.Code)
	}
}
