#!/bin/bash
# env.sh: Centralized environment variable preparation for the Autoresearch Agent

# Default RESUME to true if not set
export RESUME=${RESUME:-"true"}

# Default BUCKET_RESULTS_DIR to autoresearch-results if not set
export BUCKET_RESULTS_DIR=${BUCKET_RESULTS_DIR:-"autoresearch-results"}

# Derive BUCKET_PATH from AGENT_PROMPT for deterministic results isolation
# This ensures that even across workflow executions, the same prompt resumes the same data.
if [ -z "$BUCKET_PATH" ]; then
    DEFAULT_PROMPT="Hi have a look at program.md and let's kick off a new experiment!"
    if [ "$AGENT_PROMPT" == "$DEFAULT_PROMPT" ] || [ -z "$AGENT_PROMPT" ]; then
        export BUCKET_PATH="${BUCKET_RESULTS_DIR}/default-study"
    else
        # Slugify AGENT_PROMPT: lowercase, replace non-alnum with hyphens, trim prefix
        PROMPT_CLEAN=$(echo "$AGENT_PROMPT" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-//; s/-$//')
        PROMPT_PREFIX=$(echo "$PROMPT_CLEAN" | cut -c1-30)
        PROMPT_HASH=$(echo -n "$AGENT_PROMPT" | md5sum | cut -c1-8)
        export BUCKET_PATH="${BUCKET_RESULTS_DIR}/${PROMPT_PREFIX}-${PROMPT_HASH}"
    fi
fi

echo "Environment setup complete: BUCKET_PATH=$BUCKET_PATH, RESUME=$RESUME"
