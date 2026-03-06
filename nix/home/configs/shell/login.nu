# Nushell login-only config

# GPG signing in terminal sessions.
try {
    $env.GPG_TTY = (^tty | str trim)
} catch {
}
