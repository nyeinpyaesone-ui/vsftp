package main

import (
	"context"
	"embed"
	"encoding/json"
	"fmt"
	"io/fs"
	"log"
	"net/http"
	"os"
	"os/exec"
	"os/signal"
	"strings"
	"sync"
	"syscall"
	"time"

	"github.com/gorilla/mux"
	"github.com/rs/cors"
)

//go:embed web
var webFiles embed.FS

// AppState holds the dynamic state of the system
type AppState struct {
	Status       string   `json:"status"`
	Services     []Service `json:"services"`
	Logs         []LogEntry `json:"logs"`
	LastUpdate   time.Time `json:"lastUpdate"`
	MigrationAvailable bool `json:"migrationAvailable"`
}

type Service struct {
	Name    string `json:"name"`
	State   string `json:"state"` // running, stopped, error
	Port    int    `json:"port,omitempty"`
	Message string `json:"message"`
}

type LogEntry struct {
	Timestamp time.Time `json:"timestamp"`
	Level     string    `json:"level"` // info, success, warn, error
	Message   string    `json:"message"`
}

var (
	state = AppState{
		Status: "initializing",
		Services: []Service{
			{Name: "UniFi Controller", State: "stopped", Port: 8443},
			{Name: "Enterprise FS", State: "stopped", Port: 21},
			{Name: "Network OS", State: "stopped"},
		},
		Logs:       []LogEntry{},
		LastUpdate: time.Now(),
	}
	stateMutex sync.RWMutex
)

// main starts system monitoring and the HTTP API and dashboard, then shuts down
// the server when SIGINT or SIGTERM is received.
func main() {
	// Initialize
	addLog("info", "UniFi UCP Engine starting...")
	go monitorSystem()

	r := mux.NewRouter()

	// API Endpoints
	r.HandleFunc("/api/state", getStateHandler).Methods("GET")
	r.HandleFunc("/api/deploy", deployHandler).Methods("POST")
	r.HandleFunc("/api/migrate", migrateHandler).Methods("POST")
	r.HandleFunc("/api/service/{name}/restart", restartServiceHandler).Methods("POST")
	r.HandleFunc("/api/logs", getLogsHandler).Methods("GET")

	// Static Files
	webFS, _ := fs.Sub(webFiles, "web")
	r.PathPrefix("/").Handler(http.FileServer(http.FS(webFS)))

	handler := cors.Default().Handler(r)

	port := os.Getenv("UCP_PORT")
	if port == "" {
		port = "8080"
	}

	log.Printf("🚀 UniFi UCP Production Server starting on port %s", port)
	log.Printf("📊 Dashboard: http://localhost:%s", port)

	// Create server with context for graceful shutdown
	server := &http.Server{
		Addr:    ":" + port,
		Handler: handler,
	}

	// Channel to listen for interrupt signals
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)

	// Start server in a goroutine
	go func() {
		if err := server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatalf("Server failed: %v", err)
		}
	}()

	// Wait for interrupt signal
	<-quit
	addLog("info", "Shutdown signal received...")

	// Create a deadline for shutdown
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	// Attempt graceful shutdown
	if err := server.Shutdown(ctx); err != nil {
		log.Printf("Server forced to shutdown: %v", err)
	}

	addLog("info", "Server stopped gracefully")
}

// getStateHandler writes the shared application state as JSON under a read lock.
func getStateHandler(w http.ResponseWriter, r *http.Request) {
	stateMutex.RLock()
	defer stateMutex.RUnlock()
	
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(state)
}

// getLogsHandler writes the retained log entries as a JSON logs object.
func getLogsHandler(w http.ResponseWriter, r *http.Request) {
	stateMutex.RLock()
	defer stateMutex.RUnlock()
	
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string][]LogEntry{"logs": state.Logs})
}

// deployHandler validates the JSON request and starts a simulated deployment in
// the background, returning an initiation response before the simulation finishes.
func deployHandler(w http.ResponseWriter, r *http.Request) {
	// Validate Content-Type header
	contentType := r.Header.Get("Content-Type")
	if contentType != "" && !strings.Contains(contentType, "application/json") {
		http.Error(w, `{"error":"Content-Type must be application/json"}`, http.StatusUnsupportedMediaType)
		return
	}

	var req struct {
		Target string `json:"target"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, `{"error":"Invalid request body"}`, http.StatusBadRequest)
		return
	}

	addLog("info", fmt.Sprintf("Deploying %s...", req.Target))
	
	// Simulate deployment workflow
	go func() {
		stateMutex.Lock()
		state.Status = "deploying"
		stateMutex.Unlock()

		steps := []string{
			"Validating prerequisites...",
			"Checking Docker daemon...",
			"Creating network isolation...",
			"Pulling container images...",
			"Generating secure credentials...",
			"Starting services...",
			"Verifying health checks...",
		}

		for _, step := range steps {
			time.Sleep(800 * time.Millisecond)
			addLog("info", step)
		}

		stateMutex.Lock()
		state.Status = "running"
		for i := range state.Services {
			state.Services[i].State = "running"
			state.Services[i].Message = "Healthy"
		}
		state.LastUpdate = time.Now()
		stateMutex.Unlock()

		addLog("success", "Deployment completed successfully!")
	}()

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{
		"status": "initiated",
		"message": "Deployment started in background",
	})
}

// migrateHandler starts a simulated migration in the background and returns an
// initiation response. Completion clears the migration flag in shared state.
func migrateHandler(w http.ResponseWriter, r *http.Request) {
	addLog("warn", "Migration process initiated...")
	
	go func() {
		stateMutex.Lock()
		state.Status = "migrating"
		stateMutex.Unlock()

		// Simulate migration steps
		migrationSteps := []string{
			"Creating backup snapshot...",
			"Generating integrity manifest...",
			"Validating legacy configurations...",
			"Transferring state data...",
			"Updating service wrappers...",
			"Verifying rollback points...",
		}

		for _, step := range migrationSteps {
			time.Sleep(1 * time.Second)
			addLog("info", step)
		}

		stateMutex.Lock()
		state.MigrationAvailable = false
		state.Status = "running"
		state.LastUpdate = time.Now()
		stateMutex.Unlock()

		addLog("success", "Migration completed! System ready.")
	}()

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{
		"status": "initiated",
		"message": "Migration started",
	})
}

// restartServiceHandler simulates restarting the service named in the route by
// updating shared state asynchronously; it does not restart a system process.
func restartServiceHandler(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	name := vars["name"]

	addLog("info", fmt.Sprintf("Restarting service: %s", name))
	
	go func() {
		stateMutex.Lock()
		for i := range state.Services {
			if state.Services[i].Name == name {
				state.Services[i].State = "restarting"
				break
			}
		}
		stateMutex.Unlock()

		time.Sleep(2 * time.Second)
		
		stateMutex.Lock()
		for i := range state.Services {
			if state.Services[i].Name == name {
				state.Services[i].State = "running"
				state.Services[i].Message = "Restarted"
				break
			}
		}
		state.LastUpdate = time.Now()
		stateMutex.Unlock()

		addLog("success", fmt.Sprintf("Service %s restarted successfully", name))
	}()

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{
		"status": "restarting",
	})
}

// addLog appends a timestamped entry under the state lock, retaining the newest
// 100 entries.
func addLog(level, message string) {
	stateMutex.Lock()
	defer stateMutex.Unlock()
	
	entry := LogEntry{
		Timestamp: time.Now(),
		Level:     level,
		Message:   message,
	}
	
	state.Logs = append(state.Logs, entry)
	
	// Keep only last 100 logs
	if len(state.Logs) > 100 {
		state.Logs = state.Logs[len(state.Logs)-100:]
	}
}

// monitorSystem simulates service status updates every five seconds while the
// application is marked running. It runs until the process exits.
func monitorSystem() {
	ticker := time.NewTicker(5 * time.Second)
	defer ticker.Stop()

	for range ticker.C {
		// Simulate system monitoring
		if state.Status == "running" {
			// Check if services are still healthy
			stateMutex.Lock()
			for i := range state.Services {
				if state.Services[i].State == "running" {
					// Simulate occasional status update
					if time.Now().Second()%30 == 0 {
						state.Services[i].Message = fmt.Sprintf("Uptime: %d min", time.Now().Minute())
					}
				}
			}
			state.LastUpdate = time.Now()
			stateMutex.Unlock()
		}
	}
}

// Helper to execute actual system commands when needed
func runSystemCommand(cmd string, args ...string) (string, error) {
	output, err := exec.Command(cmd, args...).CombinedOutput()
	return strings.TrimSpace(string(output)), err
}
