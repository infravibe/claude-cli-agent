#!/usr/bin/env bash
# commands/cowork.sh - Autonomous plan, execute, verify, and self-heal workflow
# Uses JSON output to parse results and track cost/turns.

cmd_cowork() {
    local prompt=""
    local prompt_file=""
    local skip_plan="false"
    local skip_verify="false"
    local max_retries=""
    local positional=()

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -f|--file)
                [[ -n "${2:-}" ]] || die "Missing argument for --file"
                [[ -f "$2" ]] || die "File not found: $2"
                [[ -r "$2" ]] || die "File not readable: $2"
                prompt_file="$2"
                prompt="$(cat "$2")" || die "Failed to read file: $2"
                shift 2
                ;;
            -)
                prompt="$(cat)"
                shift
                ;;
            --no-plan)
                skip_plan="true"
                shift
                ;;
            --no-verify)
                skip_verify="true"
                shift
                ;;
            --retries)
                max_retries="$2"
                shift 2
                ;;
            -h|--help|help)
                cmd_cowork_help
                return 0
                ;;
            --)
                shift
                positional+=("$@")
                break
                ;;
            -*)
                die "Unknown flag for 'cowork': $1. Use 'claude-agent cowork --help' for usage."
                ;;
            *)
                positional+=("$1")
                shift
                ;;
        esac
    done

    if [[ -z "$prompt" && ${#positional[@]} -gt 0 ]]; then
        prompt="${positional[*]}"
    fi

    [[ -n "$prompt" ]] || die "No prompt provided. Usage: claude-agent cowork -f prompt.md"

    claude_check
    config_validate

    local retries="${max_retries:-$CFG_COWORK_RETRIES}"
    local work_dir="$CFG_WORKDIR"
    local session_name="cowork-$(date +%Y%m%d-%H%M%S)"
    local session_id
    session_id=$(session_create "$session_name")

    local total_cost="0"
    local total_turns="0"

    log_step "╔══════════════════════════════════════════════╗"
    log_step "║  claude-agent cowork                         ║"
    log_step "╚══════════════════════════════════════════════╝"
    log_info "Session:    $session_name ($session_id)"
    log_info "Work dir:   $work_dir"
    log_info "Retries:    $retries"
    log_info "Model:      ${CFG_MODEL:-default}"
    echo "" >&2

    # ── Phase 1: Plan ─────────────────────────────────────────────
    local plan=""
    if [[ "$skip_plan" == "false" ]]; then
        log_step "── Phase 1/3: PLAN ──────────────────────────────"
        local plan_attempt=1
        local plan_max=2
        while [[ $plan_attempt -le $plan_max ]]; do
            plan=$(cowork_plan "$prompt") && break
            local plan_rc=$?
            if [[ $plan_rc -eq 2 ]]; then
                die "Authentication error. Check ANTHROPIC_API_KEY." 2
            fi
            log_warn "Plan attempt $plan_attempt failed (exit $plan_rc)"
            plan_attempt=$((plan_attempt + 1))
        done

        if [[ -z "$plan" ]]; then
            die "Planning phase failed after $plan_max attempts"
        fi

        echo "" >&2
        echo "$plan" >&2
        echo "" >&2
        log_info "Plan generated."
    else
        log_info "Planning skipped (--no-plan)."
    fi

    # ── Phase 2+3: Execute & Verify loop ──────────────────────────
    local attempt=1
    local exec_success="false"
    local last_error=""

    while [[ $attempt -le $retries ]]; do
        echo "" >&2
        if [[ $attempt -gt 1 ]]; then
            log_step "── RETRY $attempt/$retries ───────────────────────────"
        else
            log_step "── Phase 2/3: EXECUTE ────────────────────────────"
        fi

        # Execute
        local exec_prompt
        exec_prompt=$(cowork_build_exec_prompt "$prompt" "$plan" "$last_error")

        claude_exec_json "$exec_prompt"
        local exec_rc=$?

        # Track cost
        if [[ -n "${CLAUDE_COST:-}" ]]; then
            total_cost=$(python3 -c "print(round($total_cost + ${CLAUDE_COST:-0}, 4))" 2>/dev/null || echo "$total_cost")
        fi
        if [[ -n "${CLAUDE_TURNS:-}" ]]; then
            total_turns=$(python3 -c "print($total_turns + ${CLAUDE_TURNS:-0})" 2>/dev/null || echo "$total_turns")
        fi

        # Handle auth errors immediately
        if [[ $exec_rc -eq 2 ]]; then
            die "Authentication error. Check ANTHROPIC_API_KEY." 2
        fi

        # Handle execution failure
        if [[ $exec_rc -ne 0 || "$CLAUDE_IS_ERROR" == "true" ]]; then
            log_warn "Execution failed (exit $exec_rc, attempt $attempt/$retries)"
            last_error="Execution failed with exit code $exec_rc. Output:
${CLAUDE_RESULT:-$CLAUDE_OUTPUT}"
            attempt=$((attempt + 1))
            continue
        fi

        log_info "Execution completed. Cost so far: \$${total_cost}"

        # Print the result
        if [[ -n "${CLAUDE_RESULT:-}" ]]; then
            echo "$CLAUDE_RESULT"
        fi

        # ── Phase 3: Verify ───────────────────────────────────
        if [[ "$skip_verify" == "true" ]]; then
            log_info "Verification skipped (--no-verify)."
            exec_success="true"
            break
        fi

        echo "" >&2
        log_step "── Phase 3/3: VERIFY ────────────────────────────"

        claude_exec_json "$(cowork_build_verify_prompt "$prompt" "${CLAUDE_RESULT:-}")"
        local verify_rc=$?

        # Track cost
        if [[ -n "${CLAUDE_COST:-}" ]]; then
            total_cost=$(python3 -c "print(round($total_cost + ${CLAUDE_COST:-0}, 4))" 2>/dev/null || echo "$total_cost")
        fi

        if [[ $verify_rc -eq 2 ]]; then
            die "Authentication error during verification." 2
        fi

        # Check verification result
        local verify_result="${CLAUDE_RESULT:-}"

        if cowork_check_verification "$verify_result"; then
            log_info "Verification PASSED!"
            exec_success="true"
            break
        else
            log_warn "Verification FAILED (attempt $attempt/$retries)"
            last_error="$verify_result"
            echo "" >&2
            echo "$verify_result" >&2
            attempt=$((attempt + 1))
        fi
    done

    # ── Summary ───────────────────────────────────────────────────
    echo "" >&2
    log_step "── SUMMARY ────────────────────────────────────"
    log_info "Status:     $(if [[ "$exec_success" == "true" ]]; then echo "SUCCESS"; else echo "FAILED"; fi)"
    log_info "Attempts:   $((attempt > retries ? retries : attempt))/$retries"
    log_info "Total cost: \$$total_cost"
    log_info "Total turns: $total_turns"
    log_info "Session:    $session_id"

    if [[ "$exec_success" == "true" ]]; then
        session_update "$session_id" "status" "completed"
        session_update "$session_id" "cost" "$total_cost"
        return 0
    else
        session_update "$session_id" "status" "failed"
        session_update "$session_id" "cost" "$total_cost"
        log_error "Cowork failed after $retries attempts."
        return 1
    fi
}

# ── Prompt builders ───────────────────────────────────────────────

cowork_plan() {
    local prompt="$1"

    local plan_prompt="You are a senior software architect. Analyze the following task and create a detailed, step-by-step execution plan.

TASK:
$prompt

Create a numbered plan with clear, actionable steps. For each step specify:
- What exactly needs to be done
- What files/commands are involved
- What the expected outcome is
- How to verify it worked

Be specific and thorough. This plan will be executed by an AI agent with full system access."

    _claude_build_cmd "$plan_prompt"

    (cd "$CFG_WORKDIR" && "${CLAUDE_CMD[@]}") || return $?
}

cowork_build_exec_prompt() {
    local original_task="$1"
    local plan="$2"
    local previous_error="$3"

    local exec_prompt="You have FULL root access to this system. You can read, write, delete any file, install any packages, run any command, modify any configuration. Do whatever is needed.

"

    if [[ -n "$previous_error" ]]; then
        exec_prompt+="IMPORTANT - PREVIOUS ATTEMPT FAILED. Fix these issues:
$previous_error

"
    fi

    if [[ -n "$plan" ]]; then
        exec_prompt+="EXECUTION PLAN:
$plan

"
    fi

    exec_prompt+="TASK:
$original_task

Execute every step completely. Do not ask for permission. After completing all steps, output a detailed summary of what was done, what files were created/modified, and what commands were run."

    echo "$exec_prompt"
}

cowork_build_verify_prompt() {
    local original_task="$1"
    local exec_output="$2"

    cat <<VERIFY_EOF
You are a strict QA engineer. Verify that the following task was completed correctly.

ORIGINAL TASK:
$original_task

EXECUTION SUMMARY:
$exec_output

Verification checklist:
1. Check that all requested changes/files exist and are correct
2. Run any relevant tests (pytest, npm test, go test, etc.)
3. Run any relevant linters or type checkers
4. Verify file contents match expectations
5. Check for any errors, warnings, or incomplete work
6. Check that the code compiles/runs without errors

IMPORTANT: You must end your response with EXACTLY one of these two lines:
- If everything passes: VERIFICATION_STATUS: PASS
- If anything fails: VERIFICATION_STATUS: FAIL
VERIFY_EOF
}

cowork_check_verification() {
    local result="$1"

    # Check for the explicit status line at the end of output
    # Use a strict pattern: must be on its own line, case-sensitive
    if echo "$result" | grep -q '^VERIFICATION_STATUS: PASS$'; then
        return 0
    fi

    # Also check if the last non-empty line contains the pass status
    local last_line
    last_line=$(echo "$result" | grep -v '^[[:space:]]*$' | tail -1)
    if [[ "$last_line" == "VERIFICATION_STATUS: PASS" ]]; then
        return 0
    fi

    return 1
}

cmd_cowork_help() {
    cat <<'EOF'
Usage: claude-agent cowork [OPTIONS] <PROMPT>
       claude-agent cowork -f prompt.md

Autonomous plan-execute-verify workflow with self-healing retries.

Workflow:
  1. PLAN    → Claude analyzes the task and creates a step-by-step plan
  2. EXECUTE → Claude executes the plan with full system access
  3. VERIFY  → Claude verifies everything works (runs tests, checks files)
  4. RETRY   → If verification fails, feeds errors back and re-executes

Arguments:
  <PROMPT>              Task description (can be multiple words)

Options:
  -f, --file <PATH>     Read task from a markdown file
  -                     Read task from stdin
  --no-plan             Skip planning phase, execute directly
  --no-verify           Skip verification phase
  --retries <N>         Max retry attempts (default: 3)
  -h, --help            Show this help

Environment:
  CLAUDE_AGENT_COWORK_RETRIES   Max retries (default: 3)

Examples:
  claude-agent cowork -f prompt.md
  claude-agent cowork "set up a FastAPI project with auth and tests"
  claude-agent --model opus cowork --retries 5 -f task.md
  claude-agent cowork --no-plan "fix all linting errors"
  cat task.md | claude-agent cowork -

Docker:
  docker run --rm -e ANTHROPIC_API_KEY -v $(pwd):/workspace \
      claude-agent cowork -f /workspace/prompt.md
EOF
}
