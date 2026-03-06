# Nushell startup config

# Yazi: open file manager and sync cwd back to current shell.
def --env y [...args] {
    let tmp = (mktemp -t "yazi-cwd.XXXXXX" | str trim)
    try {
        ^yazi ...$args --cwd-file $tmp
    } catch {
    }

    if ($tmp | path exists) {
        let cwd = (open --raw $tmp | str trim)
        if (($cwd | str length) > 0 and $cwd != $env.PWD) {
            cd $cwd
        }
    }

    rm -f $tmp
}

# Claude Code helper.
def --wrapped ccv [...args] {
    with-env {
        ENABLE_BACKGROUND_TASKS: "true"
        FORCE_AUTO_BACKGROUND_TASKS: "true"
        CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC: "true"
        CLAUDE_CODE_ENABLE_UNIFIED_READ_TOOL: "true"
    } {
        if (($args | length) > 0 and (($args | first) == "r")) {
            claude --dangerously-skip-permissions --resume ...($args | skip 1)
        } else {
            claude --dangerously-skip-permissions ...$args
        }
    }
}

# Codex helper.
def --wrapped cdx [...args] {
    if (($args | length) > 0 and (($args | first) == "r")) {
        codex resume ...($args | skip 1)
    } else {
        codex --dangerously-bypass-approvals-and-sandbox ...$args
    }
}

# Global fuzzy search helper.
def frg [scope?: string] {
    let selected_scope = ($scope | default "")
    let depth = if ($selected_scope == "l" or $selected_scope == "1") {
        "--max-depth 1"
    } else {
        ""
    }

    ^fzf --ansi --bind $"change:reload:
      if [[ -n {q} ]]; then
        rg ($depth) --line-number --no-heading --color=always {q};
      else
        rg ($depth) --files;
      fi || true" --preview "bat --style=numbers --color=always --highlight-line {2} {1}" --delimiter ":"
}
