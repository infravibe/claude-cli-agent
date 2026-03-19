#!/usr/bin/env bash
# session.sh - Session management for multi-turn conversations
# Uses safe Python operations (no string interpolation in Python code)

session_ensure_dir() {
    mkdir -p "$CFG_SESSION_DIR" || die "Cannot create session directory: $CFG_SESSION_DIR"
}

session_create() {
    local name="${1:-session-$(date +%Y%m%d-%H%M%S)}"
    # Sanitize the name to prevent injection
    name=$(sanitize "$name")
    [[ -z "$name" ]] && name="session-$(date +%s)"

    local id
    id=$(gen_uuid)
    session_ensure_dir

    local ts
    ts=$(now_utc)

    json_create "$CFG_SESSION_DIR/$id.json" \
        "id=$id" \
        "name=$name" \
        "created=$ts" \
        "last_used=$ts" \
        "turns=0" \
        "workdir=$CFG_WORKDIR" \
        "status=active"

    echo "$id"
}

session_list() {
    session_ensure_dir

    # Check if any json files exist
    local count
    count=$(find "$CFG_SESSION_DIR" -maxdepth 1 -name '*.json' 2>/dev/null | wc -l | xargs)

    if [[ "$count" -eq 0 ]]; then
        log_info "No sessions found."
        return 0
    fi

    printf "${BOLD}%-38s %-20s %-5s %-8s %s${RESET}\n" "SESSION ID" "NAME" "TURNS" "STATUS" "LAST USED"
    for f in "$CFG_SESSION_DIR"/*.json; do
        [[ -f "$f" ]] || continue
        local id name turns last_used status
        id=$(json_get "$f" "id")
        name=$(json_get "$f" "name")
        turns=$(json_get "$f" "turns")
        status=$(json_get "$f" "status")
        last_used=$(json_get "$f" "last_used")
        printf "%-38s %-20s %-5s %-8s %s\n" "$id" "$name" "$turns" "$status" "$last_used"
    done
}

session_get() {
    local id="$1"
    id=$(sanitize "$id")
    local file="$CFG_SESSION_DIR/$id.json"
    [[ -f "$file" ]] || die "Session not found: $id"
    cat "$file"
}

session_update() {
    local id="$1" key="$2" value="$3"
    id=$(sanitize "$id")
    local file="$CFG_SESSION_DIR/$id.json"
    [[ -f "$file" ]] || return 0
    json_set "$file" "$key" "$value"
}

session_increment_turns() {
    local id="$1"
    id=$(sanitize "$id")
    local file="$CFG_SESSION_DIR/$id.json"
    [[ -f "$file" ]] || return 0

    python3 - "$file" "$(now_utc)" <<'PYEOF'
import json, sys
filepath, ts = sys.argv[1], sys.argv[2]
try:
    with open(filepath) as f:
        d = json.load(f)
    d['turns'] = d.get('turns', 0) + 1
    d['last_used'] = ts
    with open(filepath, 'w') as f:
        json.dump(d, f, indent=2)
except (FileNotFoundError, json.JSONDecodeError):
    pass
PYEOF
}

session_delete() {
    local id="$1"
    id=$(sanitize "$id")
    local file="$CFG_SESSION_DIR/$id.json"
    [[ -f "$file" ]] || die "Session not found: $id"
    rm -f "$file"
    log_info "Deleted session: $id"
}

# Resolve a session by name or ID
session_resolve() {
    local query="$1"
    session_ensure_dir

    # Direct ID match (sanitize for safe file path)
    local safe_query
    safe_query=$(sanitize "$query")
    if [[ -f "$CFG_SESSION_DIR/$safe_query.json" ]]; then
        echo "$safe_query"
        return 0
    fi

    # Name match
    for f in "$CFG_SESSION_DIR"/*.json; do
        [[ -f "$f" ]] || continue
        local name
        name=$(json_get "$f" "name")
        if [[ "$name" == "$safe_query" ]]; then
            json_get "$f" "id"
            return 0
        fi
    done

    return 1
}
