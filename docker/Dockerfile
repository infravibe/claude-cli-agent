FROM ubuntu:22.04

# ── Root with full unrestricted access ────────────────────────────
USER root
ENV DEBIAN_FRONTEND=noninteractive
ENV HOME=/root
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8

# ── System dependencies ──────────────────────────────────────────
RUN apt-get update && apt-get install -y --no-install-recommends \
    # Core
    bash \
    curl \
    wget \
    git \
    ca-certificates \
    gnupg \
    # Python (for JSON ops, scripting)
    python3 \
    python3-pip \
    python3-venv \
    # Build tools (Claude may need to compile)
    build-essential \
    cmake \
    pkg-config \
    # Common dev tools
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

# ── Pre-accept Claude Code onboarding (non-interactive) ──────────
RUN mkdir -p /root/.claude && \
    echo '{"hasCompletedOnboarding":true,"hasAcknowledgedCostThreshold":true}' \
    > /root/.claude/settings.json

# ── Install claude-agent ─────────────────────────────────────────
COPY claude-agent /usr/local/lib/claude-agent/claude-agent
COPY lib/ /usr/local/lib/claude-agent/lib/
COPY commands/ /usr/local/lib/claude-agent/commands/
RUN chmod +x /usr/local/lib/claude-agent/claude-agent \
    && ln -sf /usr/local/lib/claude-agent/claude-agent /usr/local/bin/claude-agent

# ── Environment: full permissions, no restrictions ────────────────
ENV CLAUDE_AGENT_SKIP_PERMISSIONS=true
ENV CLAUDE_AGENT_WORKDIR=/workspace

# ── Health check ──────────────────────────────────────────────────
HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
    CMD claude-agent version > /dev/null 2>&1

WORKDIR /workspace

# API key at runtime: docker run -e ANTHROPIC_API_KEY=sk-ant-...
ENTRYPOINT ["claude-agent"]
CMD ["--help"]
