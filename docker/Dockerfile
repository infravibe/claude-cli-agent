FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8

# ── Install everything as root ────────────────────────────────────
USER root

# ── System dependencies ──────────────────────────────────────────
RUN apt-get update && apt-get install -y --no-install-recommends \
    # Core
    bash \
    curl \
    wget \
    git \
    ca-certificates \
    gnupg \
    # Python
    python3 \
    python3-pip \
    python3-venv \
    # Build tools
    build-essential \
    cmake \
    pkg-config \
    # Dev tools
    jq \
    tree \
    vim-tiny \
    less \
    unzip \
    zip \
    tar \
    gzip \
    # Networking
    openssh-client \
    netcat-openbsd \
    dnsutils \
    iputils-ping \
    # Process management
    sudo \
    procps \
    # Timeout support
    coreutils \
    && rm -rf /var/lib/apt/lists/*

# ── Node.js 20 LTS ──────────────────────────────────────────────
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/*

# ── Claude Code CLI ──────────────────────────────────────────────
RUN npm install -g @anthropic-ai/claude-code

# ── Create non-root user with sudo access ─────────────────────────
# Claude Code blocks --dangerously-skip-permissions under root,
# so we run as a regular user with passwordless sudo for full access.
RUN useradd -m -s /bin/bash -G sudo claude && \
    echo "claude ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/claude && \
    chmod 0440 /etc/sudoers.d/claude

# ── Pre-accept Claude Code onboarding ────────────────────────────
RUN mkdir -p /home/claude/.claude && \
    echo '{"hasCompletedOnboarding":true,"hasAcknowledgedCostThreshold":true}' \
    > /home/claude/.claude/settings.json && \
    echo '{}' > /home/claude/.claude.json && \
    chown -R claude:claude /home/claude/.claude /home/claude/.claude.json

# ── Install claude-agent ─────────────────────────────────────────
COPY claude-agent /usr/local/lib/claude-agent/claude-agent
COPY lib/ /usr/local/lib/claude-agent/lib/
COPY commands/ /usr/local/lib/claude-agent/commands/
RUN chmod +x /usr/local/lib/claude-agent/claude-agent \
    && ln -sf /usr/local/lib/claude-agent/claude-agent /usr/local/bin/claude-agent

# ── Workspace & session directory setup ───────────────────────────
RUN mkdir -p /workspace && chown claude:claude /workspace && \
    mkdir -p /home/claude/.config/claude-agent/sessions && \
    chown -R claude:claude /home/claude/.config

# ── Switch to non-root user ──────────────────────────────────────
USER claude
ENV HOME=/home/claude
ENV CLAUDE_AGENT_SKIP_PERMISSIONS=true
ENV CLAUDE_AGENT_WORKDIR=/workspace

WORKDIR /workspace

# ── Health check ─────────────────────────────────────────────────
HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
    CMD claude-agent version > /dev/null 2>&1

# API key at runtime: docker run -e ANTHROPIC_API_KEY=sk-ant-...
ENTRYPOINT ["claude-agent"]
CMD ["--help"]
