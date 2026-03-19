#!/usr/bin/env bash
# core.sh - Core utilities (logging, error handling, safe helpers)

CLAUDE_AGENT_VERSION="2.0.0"

# Colors (disabled if not a terminal)
if [[ -t 2 ]]; then
    RED='\033[0;31m'
    YELLOW='\033[0;33m'
    GREEN='\033[0;32m'
    BLUE='\033[0;34m'
    BOLD='\033[1m'
    DIM='\033[2m'
    RESET='\033[0m'
else
    RED='' YELLOW='' GREEN='' BLUE='' BOLD='' DIM='' RESET=''
fi

log_info()  { echo -e "${GREEN}[INFO]${RESET} $*" >&2; }
log_warn()  { echo -e "${YELLOW}[WARN]${RESET} $*" >&2; }
log_error() { echo -e "${RED}[ERROR]${RESET} $*" >&2; }
log_debug() {
    if [[ "${CFG_VERBOSE:-false}" == "true" ]]; then
        echo -e "${BLUE}[DEBUG]${RESET} $*" >&2
    fi
}
log_step() { echo -e "${BOLD}$*${RESET}" >&2; }

die() {
    log_error "$1"
    exit "${2:-1}"
}

require_cmd() {
    command -v "$1" &>/dev/null || die "'$1' is required but not installed. Run the installer or install it manually."
}

# ── Safe JSON operations (no shell injection) ─────────────────────
# All Python operations use sys.argv or heredocs instead of string interpolation

# Read a field from a JSON file safely
json_get() {
    local file="$1" key="$2"
    python3 - "$file" "$key" <<'PYEOF'
import json, sys
try:
    with open(sys.argv[1]) as f:
        d = json.load(f)
    print(d.get(sys.argv[2], ''))
except (FileNotFoundError, json.JSONDecodeError, IndexError):
    pass
PYEOF
}

# Set a field in a JSON file safely
json_set() {
    local file="$1" key="$2" value="$3"
    python3 - "$file" "$key" "$value" <<'PYEOF'
import json, sys
filepath, key, value = sys.argv[1], sys.argv[2], sys.argv[3]
try:
    with open(filepath) as f:
        d = json.load(f)
except (FileNotFoundError, json.JSONDecodeError):
    d = {}
# Try to convert numeric strings
try:
    value = int(value)
except ValueError:
    pass
d[key] = value
with open(filepath, 'w') as f:
    json.dump(d, f, indent=2)
PYEOF
}

# Create a JSON file from key=value pairs safely
json_create() {
    local file="$1"
    shift
    python3 - "$file" "$@" <<'PYEOF'
import json, sys
filepath = sys.argv[1]
d = {}
for arg in sys.argv[2:]:
    key, _, value = arg.partition('=')
    try:
        value = int(value)
    except ValueError:
        pass
    d[key] = value
with open(filepath, 'w') as f:
    json.dump(d, f, indent=2)
PYEOF
}

# Parse a field from JSON string on stdin
json_parse() {
    local key="$1"
    python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
    val = d.get('$key', '')
    if isinstance(val, (dict, list)):
        print(json.dumps(val))
    else:
        print(val)
except (json.JSONDecodeError, KeyError):
    pass
"
}

# Check if a JSON field indicates error
json_is_error() {
    python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
    if d.get('is_error', False):
        sys.exit(0)
    else:
        sys.exit(1)
except (json.JSONDecodeError, KeyError):
    sys.exit(1)
"
}

# Generate a UUID v4
gen_uuid() {
    if [[ -f /proc/sys/kernel/random/uuid ]]; then
        cat /proc/sys/kernel/random/uuid
    else
        python3 -c "import uuid; print(uuid.uuid4())"
    fi
}

# Timestamp in ISO 8601 UTC
now_utc() {
    date -u +"%Y-%m-%dT%H:%M:%SZ"
}

# Sanitize a string for safe use (alphanumeric, dash, underscore, dot only)
sanitize() {
    echo "$1" | tr -cd '[:alnum:]._-'
}

# Run a command with a timeout (seconds). Falls back to no-timeout if timeout cmd missing.
run_with_timeout() {
    local timeout_secs="$1"
    shift
    if command -v timeout &>/dev/null; then
        timeout "$timeout_secs" "$@"
    elif command -v gtimeout &>/dev/null; then
        gtimeout "$timeout_secs" "$@"
    else
        "$@"
    fi
}
