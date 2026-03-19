# Bash completion for claude-agent
_claude_agent() {
    local cur prev words cword
    _init_completion || return

    local commands="run cowork chat session config version help"
    local global_opts="--model --output --tools --max-turns --max-budget --system-prompt --system-prompt-file --workdir --api-key --mcp-config --continue --resume --no-skip-permissions --verbose --help --version"

    case "${prev}" in
        --model)
            COMPREPLY=($(compgen -W "sonnet opus haiku" -- "$cur"))
            return
            ;;
        --output)
            COMPREPLY=($(compgen -W "text json stream-json" -- "$cur"))
            return
            ;;
        --workdir|-w|--system-prompt-file|--mcp-config)
            _filedir
            return
            ;;
        -f|--file)
            _filedir
            return
            ;;
        session)
            COMPREPLY=($(compgen -W "list show delete help" -- "$cur"))
            return
            ;;
        config)
            COMPREPLY=($(compgen -W "show set path help" -- "$cur"))
            return
            ;;
    esac

    if [[ ${cword} -eq 1 ]]; then
        COMPREPLY=($(compgen -W "${commands}" -- "$cur"))
        return
    fi

    COMPREPLY=($(compgen -W "${global_opts}" -- "$cur"))
}

complete -F _claude_agent claude-agent
