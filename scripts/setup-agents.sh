#!/usr/bin/env bash
# Install the three class agents. Log in afterward with codex-login.sh / claude-login.sh.
npm install -g @openai/codex
npm install -g @anthropic-ai/claude-code
curl -fsSL https://antigravity.google/cli/install.sh | bash
