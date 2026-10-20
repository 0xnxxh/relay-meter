#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
OMC_ROOT="$(cd "${1:?usage: $0 /path/to/oh-my-cpa}" && pwd)"
mkdir -p "$OMC_ROOT/tmp"
TEST_DIR="$(mktemp -d "$OMC_ROOT/tmp/relay-meter-test.XXXXXX")"
SERVER_PID=""
cleanup() {
  if [[ -n "$SERVER_PID" ]]; then
    kill "$SERVER_PID" 2>/dev/null || true
    wait "$SERVER_PID" 2>/dev/null || true
  fi
  rm -rf "$TEST_DIR"
}
trap cleanup EXIT
if ! git -C "$OMC_ROOT" check-ignore -q "$TEST_DIR/main.go"; then
  echo "upstream tmp/ must be ignored for the disposable integration fixture" >&2
  exit 1
fi

# Real console router/auth/database, seeded with five disposable usage events.
# No upstream gateway, existing configuration, or persistent database is used.
cat > "$TEST_DIR/main.go" <<'GO'
package main

import (
	"context"
	"encoding/json"
	"log"
	"net"
	"net/http"
	"os"
	"time"

	"github.com/oh-my-cpa/oh-my-cpa/internal/api"
	"github.com/oh-my-cpa/oh-my-cpa/internal/auth"
	"github.com/oh-my-cpa/oh-my-cpa/internal/config"
	"github.com/oh-my-cpa/oh-my-cpa/internal/crypto"
	"github.com/oh-my-cpa/oh-my-cpa/internal/domain"
	"github.com/oh-my-cpa/oh-my-cpa/internal/repository"
	"github.com/oh-my-cpa/oh-my-cpa/internal/usage"
)

func main() {
	ctx := context.Background()
	cipher, err := crypto.New("01234567890123456789012345678901")
	must(err)
	db, err := repository.Open(ctx, "file:relay_meter_acceptance?mode=memory&cache=shared", repository.WithCipher(cipher))
	must(err)
	defer db.Close()
	repo := repository.New(db)
	now := time.Now()
	encrypted, nonce, err := cipher.Encrypt([]byte("relay-meter-disposable-test-key"))
	must(err)
	must(repo.UpsertInstance(ctx, domain.CPAInstance{ID: "default", Name: "Acceptance", BaseURL: "http://127.0.0.1:1", ManagementKeyCiphertext: encrypted, ManagementKeyNonce: nonce, CreatedAt: now, UpdatedAt: now}))
	events := []usage.Event{}
	for i, ago := range []time.Duration{5 * time.Minute, 7 * time.Minute, 10 * time.Minute, 48 * time.Hour, 40 * 24 * time.Hour} {
		model := "acceptance-model-a"
		if i%2 == 1 {
			model = "acceptance-model-b"
		}
		ttft := int64(80)
		events = append(events, usage.Event{InstanceID: "default", EventKey: time.Duration(i).String(), RequestID: time.Duration(i).String(), APIGroupKey: "acceptance-caller", Model: model, Provider: "acceptance", TimestampMS: now.Add(-ago).UnixMilli(), Failed: i == 2, Generate: true, LatencyMS: 250, TTFTMS: &ttft, InputTokens: 1000, OutputTokens: 500, CacheReadTokens: 200, TotalTokens: 1500})
	}
	_, err = repo.InsertUsageEvents(ctx, events)
	must(err)
	manager, err := auth.New("relay-meter-disposable-test-key", "/omc", "")
	must(err)
	handler := api.NewHandler(config.Config{BasePath: "/omc", Version: "acceptance", RequestTimeout: 5 * time.Second}, repo, cipher, nil, manager)
	listener, err := net.Listen("tcp", "127.0.0.1:0")
	must(err)
	endpoint := "http://" + listener.Addr().String() + "/omc"
	must(os.WriteFile(os.Getenv("RELAY_METER_OMC_ENDPOINT_FILE"), mustJSON(map[string]string{"url": endpoint}), 0600))
	log.Print("isolated OMC handler ready")
	must(http.Serve(listener, handler.Router()))
}
func must(err error) {
	if err != nil {
		log.Fatal(err)
	}
}
func mustJSON(v any) []byte { b, err := json.Marshal(v); must(err); return b }
GO
(
  cd "$OMC_ROOT"
  go build -o "$TEST_DIR/server" "$TEST_DIR/main.go"
)
RELAY_METER_OMC_ENDPOINT_FILE="$TEST_DIR/endpoint.json" "$TEST_DIR/server" >"$TEST_DIR/server.log" 2>&1 &
SERVER_PID=$!
for attempt in {1..100}; do
  if [[ -s "$TEST_DIR/endpoint.json" ]]; then break; fi
  if ! kill -0 "$SERVER_PID" 2>/dev/null; then
    cat "$TEST_DIR/server.log" >&2
    exit 1
  fi
  sleep 0.1
done
if [[ ! -s "$TEST_DIR/endpoint.json" ]]; then
  echo "isolated OMC handler did not start" >&2
  cat "$TEST_DIR/server.log" >&2
  exit 1
fi
RELAY_METER_OMC_TEST_URL="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["url"])' "$TEST_DIR/endpoint.json")" \
RELAY_METER_OMC_TEST_KEY=relay-meter-disposable-test-key \
  "$ROOT_DIR/scripts/run_characterization_tests.sh"
