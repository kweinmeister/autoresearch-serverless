#!/bin/bash
set -e

# Load environment variables
source ./env.sh

RESUMED=false
if [ "${RESUME,,}" == "true" ] && [ -f "/mnt/results/${BUCKET_PATH}/git_history.tar.gz" ]; then
    echo "Found existing experiment state. Resuming..."
    if tar -xzf "/mnt/results/${BUCKET_PATH}/git_history.tar.gz" -C /app/ --no-same-owner --no-same-permissions 2>/dev/null; then
        git reset --hard HEAD
        cp "/mnt/results/${BUCKET_PATH}/results.tsv" /app/ 2>/dev/null || true
        echo "Resume complete."
        RESUMED=true
    else
        echo "WARNING: Checkpoint archive is corrupted. Removing and starting fresh."
        rm -f "/mnt/results/${BUCKET_PATH}/git_history.tar.gz"
    fi
fi

if [ "$RESUMED" != "true" ]; then
    echo "Starting fresh experiment (Resume: $RESUME)."
    if [ ! -f /app/results.tsv ]; then
        echo -e "commit\tval_bpb\tmemory_gb\tstatus\tdescription" > /app/results.tsv
    fi
    if [ ! -d .git ]; then
        git init
        git add .
        git commit -m "Initial commit"
    fi
    git branch -M master
fi
