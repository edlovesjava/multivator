FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

# Base tooling
RUN apt-get update && apt-get install -y \
    curl git jq build-essential ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Node.js 22
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
    && apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/*

# Claude Code CLI
RUN npm install -g @anthropic-ai/claude-code

# Working directory
WORKDIR /workspace

CMD ["/bin/bash"]
