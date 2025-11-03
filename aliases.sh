# Global aliases (loaded for login shells via /etc/profile)

# Colors for ls if supported (BusyBox/GNU)
if ls --color=auto >/dev/null 2>&1; then
  alias ls='ls --color=auto'
elif ls --colour=auto >/dev/null 2>&1; then
  alias ls='ls --colour=auto'
fi

# Vanliga ls-alias
alias ll='ls -alFh'
alias la='ls -A'
alias l='ls -CF'
