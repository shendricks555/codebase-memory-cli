# ============================================================================
#  Claude Code Dev Container - C Theme
#  Powered by Starship (https://starship.rs)
#  Optimized for C/C++ project building
# ============================================================================

autoload -U colors && colors

# ----------------------------------------------------------------------------
#  Starship Prompt Initialization
# ----------------------------------------------------------------------------
eval "$(starship init zsh)"

# ----------------------------------------------------------------------------
#  Directory Colors
# ----------------------------------------------------------------------------
export CLICOLOR=1
export LSCOLORS=GxFxCxDxBxegedabagaced
export LS_COLORS='di=1;36:ln=1;35:so=1;32:pi=1;33:ex=1;31:bd=34;46:cd=34;43:su=30;41:sg=30;46:tw=30;42:ow=30;43'

# ----------------------------------------------------------------------------
#  Aliases - Core
# ----------------------------------------------------------------------------
alias ls='ls --color=auto'
alias ll='ls -lah --color=auto'
alias la='ls -A --color=auto'
alias l='ls -CF --color=auto'
alias grep='grep --color=auto'
alias tree='tree -C'

# ----------------------------------------------------------------------------
#  Aliases - Navigation
# ----------------------------------------------------------------------------
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias ws='cd /workspace'

# ----------------------------------------------------------------------------
#  Aliases - Claude Code
# ----------------------------------------------------------------------------
alias c='claude --dangerously-skip-permissions'
alias ch='claude --dangerously-skip-permissions -p "Use hierarchical Task agents"'

# ----------------------------------------------------------------------------
#  Aliases - OpenCode and TUI Tools
# ----------------------------------------------------------------------------
alias oc='opencode'

alias lg='lazygit'
alias lzd='lazydocker'
alias top='btop'

# ----------------------------------------------------------------------------
#  Aliases - C/C++ build
# ----------------------------------------------------------------------------
alias mk='make'
alias mkc='make clean'
alias cb='cmake -B build'
alias cbb='cmake --build build'
alias cbt='ctest --test-dir build'
alias vg='valgrind --leak-check=full'

# ----------------------------------------------------------------------------
#  Aliases - Git
# ----------------------------------------------------------------------------
alias g='git'
alias gs='git status -sb'
alias ga='git add'
alias gaa='git add -A'
alias gc='git commit'
alias gcm='git commit -m'
alias gca='git commit --amend'
alias gp='git push'
alias gpf='git push --force-with-lease'
alias gl='git pull'
alias gf='git fetch'
alias gd='git diff'
alias gds='git diff --staged'
alias gb='git branch'
alias gco='git checkout'
alias gcb='git checkout -b'
alias glog='git log --oneline --graph --decorate -15'
alias gloga='git log --oneline --graph --decorate --all -20'
alias gst='git stash'
alias gstp='git stash pop'

# ----------------------------------------------------------------------------
#  Aliases - Docker
# ----------------------------------------------------------------------------
alias d='docker'
alias dc='docker compose'
alias dps='docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"'
alias dpsa='docker ps -a --format "table {{.Names}}\t{{.Status}}"'
alias dlog='docker logs -f'

# ----------------------------------------------------------------------------
#  History Configuration
# ----------------------------------------------------------------------------
HISTSIZE=50000
SAVEHIST=50000
# Use volume-mounted directory for persistent history
mkdir -p ~/.zsh_history_dir 2>/dev/null
HISTFILE=~/.zsh_history_dir/.zsh_history

# History behavior options
setopt SHARE_HISTORY          # Share history across terminals
setopt HIST_IGNORE_DUPS       # Ignore consecutive duplicates
setopt HIST_IGNORE_ALL_DUPS   # Remove older duplicates from history
setopt HIST_IGNORE_SPACE      # Don't save commands starting with space
setopt HIST_REDUCE_BLANKS     # Remove extra whitespace
setopt INC_APPEND_HISTORY     # Write immediately, not on shell exit
setopt HIST_FIND_NO_DUPS      # Don't show dupes when searching
setopt HIST_VERIFY            # Show command before executing from history
setopt HIST_EXPIRE_DUPS_FIRST # Remove duplicates first when trimming
setopt EXTENDED_HISTORY       # Save timestamps with history

# ----------------------------------------------------------------------------
#  Tab Completion
# ----------------------------------------------------------------------------
autoload -Uz compinit && compinit -u
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*:descriptions' format '%F{yellow}-- %d --%f'
zstyle ':completion:*:warnings' format '%F{red}No matches%f'
zstyle ':completion:*' group-name ''

# ----------------------------------------------------------------------------
#  Key Bindings
# ----------------------------------------------------------------------------
# Force emacs mode (consistent behavior regardless of EDITOR setting)
bindkey -e

# Up/Down arrow - history search (support both normal and application mode)
bindkey '^[[A' up-line-or-search      # Up arrow (normal mode)
bindkey '^[[B' down-line-or-search    # Down arrow (normal mode)
bindkey '^[OA' up-line-or-search      # Up arrow (application mode - IDEs)
bindkey '^[OB' down-line-or-search    # Down arrow (application mode - IDEs)

# Home/End (both modes)
bindkey '^[[H' beginning-of-line      # Home (normal)
bindkey '^[[F' end-of-line            # End (normal)
bindkey '^[OH' beginning-of-line      # Home (application mode)
bindkey '^[OF' end-of-line            # End (application mode)
bindkey '^[[1~' beginning-of-line     # Home (alternate)
bindkey '^[[4~' end-of-line           # End (alternate)

# Other keys
bindkey '^[[3~' delete-char           # Delete
bindkey '^R' history-incremental-search-backward  # Ctrl+R reverse search
bindkey '^S' history-incremental-search-forward   # Ctrl+S forward search

# ----------------------------------------------------------------------------
#  Environment
# ----------------------------------------------------------------------------
export PATH="$HOME/.local/bin:/usr/bin:$PATH"
export EDITOR=vim
export LANG=en_US.UTF-8

# ----------------------------------------------------------------------------
#  Auto-cd to Workspace on Shell Start
# ----------------------------------------------------------------------------
# /workspace IS the project root - always start there
cd /workspace 2>/dev/null || true

# ----------------------------------------------------------------------------
#  Welcome Message
# ----------------------------------------------------------------------------
print_welcome() {
    # Colors darkened 20% toward black for subdued terminal appearance
    local orange='\033[38;2;164;130;0m'
    local cyan='\033[38;2;0;164;164m'
    local green='\033[38;2;0;164;0m'
    local yellow='\033[38;2;164;164;0m'
    local blue='\033[38;2;0;0;190m'
    local purple='\033[38;2;164;0;164m'
    local white='\033[38;2;204;204;204m'
    local dim='\033[2m'
    local reset='\033[0m'
    local bold='\033[1m'

    echo ""
    echo "${orange}+--------------------------------------------------------------------+${reset}"
    echo "${orange}|${reset}  ${white}${bold}CLAUDE CODE DEV CONTAINER${reset} ${dim}(C)${reset}                                   ${orange}|${reset}"
    echo "${orange}+--------------------------------------------------------------------+${reset}"
    echo "${orange}|${reset}                                                                    ${orange}|${reset}"
    echo "${orange}|${reset}  ${green}Claude${reset}      ${dim}c${reset}                    ${dim}claude --dangerously-skip-permissions${reset}"
    echo "${orange}|${reset}                                                                    ${orange}|${reset}"
    echo "${orange}|${reset}  ${cyan}Make${reset}        ${dim}mk${reset}   ${dim}mkc${reset}             ${dim}make  make clean${reset}"
    echo "${orange}|${reset}                                                                    ${orange}|${reset}"
    echo "${orange}|${reset}  ${purple}CMake${reset}       ${dim}cb${reset}   ${dim}cbb${reset}  ${dim}cbt${reset}        ${dim}configure  build  test${reset}"
    echo "${orange}|${reset}                                                                    ${orange}|${reset}"
    echo "${orange}|${reset}  ${blue}Valgrind${reset}    ${dim}vg${reset}                   ${dim}leak-check=full${reset}"
    echo "${orange}|${reset}                                                                    ${orange}|${reset}"
    echo "${orange}|${reset}  ${yellow}Git${reset}         ${dim}gs${reset}   ${dim}ga${reset}   ${dim}gc${reset}   ${dim}gp${reset}    ${dim}status  add  commit  push${reset}"
    echo "${orange}|${reset}              ${dim}gd${reset}   ${dim}glog${reset}  ${dim}gco${reset}        ${dim}diff  log  checkout${reset}"
    echo "${orange}|${reset}                                                                    ${orange}|${reset}"
    echo "${orange}+--------------------------------------------------------------------+${reset}"

    # System info
    local gcc_ver=$(gcc --version 2>/dev/null | head -1 || echo "n/a")
    local cmake_ver=$(cmake --version 2>/dev/null | head -1 || echo "n/a")

    echo ""
    echo "${dim}  ${gcc_ver}${reset}"
    echo "${dim}  ${cmake_ver}${reset}"
    echo ""
}

# Only show welcome on interactive login
[[ -o interactive ]] && print_welcome
