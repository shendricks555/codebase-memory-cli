# C Dev Container
# Includes: gcc/clang toolchain, make, cmake, zlib, Claude Code
FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# =============================================================================
# SYSTEM PACKAGES (as root)
# =============================================================================
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    clang \
    lldb \
    gdb \
    make \
    cmake \
    pkg-config \
    zlib1g-dev \
    libssl-dev \
    valgrind \
    git \
    git-daemon-run \
    curl wget unzip \
    ripgrep fzf jq vim zsh ca-certificates \
    procps sudo locales \
    netcat-openbsd \
    python3 python3-pip \
    btop \
    && apt-get clean && rm -rf /var/lib/apt/lists/* \
    && locale-gen en_US.UTF-8

ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8

# =============================================================================
# USER SETUP — own "claude" user on a plain Ubuntu base (no MS devcontainer
# base image involved, so none of the vscode/updateRemoteUserUID permission
# issues documented in the .NET platform's CONTAINER-PERMISSIONS.md apply)
# =============================================================================
ARG USERNAME=claude
ARG USER_UID=1000
ARG USER_GID=1000

RUN groupadd --gid ${USER_GID} ${USERNAME} \
    && useradd --uid ${USER_UID} --gid ${USER_GID} -m -s /bin/zsh ${USERNAME} \
    && echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/${USERNAME} \
    && chmod 0440 /etc/sudoers.d/${USERNAME}

# NOTE: GitHub CLI intentionally NOT installed
# Container should have NO GitHub access - all GitHub operations go through host machine

# =============================================================================
# DEVELOPER TOOLS (as root -> /usr/local/bin)
# =============================================================================
# Starship prompt
RUN curl -sS https://starship.rs/install.sh | sh -s -- -y

# lazygit
RUN LAZYGIT_VERSION=$(curl -s "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" | jq -r '.tag_name' | sed 's/v//') \
    && curl -Lo /tmp/lazygit.tar.gz "https://github.com/jesseduffield/lazygit/releases/latest/download/lazygit_${LAZYGIT_VERSION}_Linux_x86_64.tar.gz" \
    && tar -xzf /tmp/lazygit.tar.gz -C /usr/local/bin lazygit \
    && chmod 755 /usr/local/bin/lazygit \
    && rm /tmp/lazygit.tar.gz

# lazydocker
RUN curl https://raw.githubusercontent.com/jesseduffield/lazydocker/master/scripts/install_update_linux.sh | bash \
    && mv /root/.local/bin/lazydocker /usr/local/bin/lazydocker \
    && chmod 755 /usr/local/bin/lazydocker

# =============================================================================
# DIRECTORIES & PERMISSIONS (as root, before switching to claude user)
# =============================================================================
RUN mkdir -p /workspace /home/${USERNAME}/.claude \
    /home/${USERNAME}/.local/bin /home/${USERNAME}/.local/share \
    && chown -R ${USER_UID}:${USER_GID} /home/${USERNAME} /workspace

# =============================================================================
# SHELL CONFIGURATION
# =============================================================================
# Copy to /etc/skel as backup (entrypoint restores if volume mount wipes home)
RUN mkdir -p /etc/skel/.config
COPY config/.zshrc /etc/skel/.zshrc
COPY config/starship.toml /etc/skel/.config/starship.toml

COPY config/.zshrc /home/${USERNAME}/.zshrc
RUN mkdir -p /home/${USERNAME}/.config
COPY config/starship.toml /home/${USERNAME}/.config/starship.toml
RUN chown -R ${USER_UID}:${USER_GID} /home/${USERNAME}

# =============================================================================
# SCRIPTS
# =============================================================================
COPY scripts/ /usr/local/bin/
RUN chmod 755 /usr/local/bin/*.sh

# =============================================================================
# CLAUDE CODE (native installer, own user's home directory — no MS base image
# home-directory quirks to work around, so the plain approach is sufficient)
# =============================================================================
ENV HOME=/home/${USERNAME}
ENV PATH="/home/${USERNAME}/.local/bin:${PATH}"
USER ${USERNAME}
WORKDIR /workspace

RUN curl -fsSL https://claude.ai/install.sh | bash

# =============================================================================
# VERIFY CLAUDE CODE — build FAILS here if broken
# =============================================================================
RUN echo "=== Claude Code Verification ===" \
    && echo "User: $(whoami) ($(id))" \
    && which claude \
    && claude --version \
    && echo "=== OK: claude works as ${USERNAME} user ==="

# =============================================================================
# PORTS & ENTRYPOINT
# =============================================================================
EXPOSE 47418

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["zsh"]
