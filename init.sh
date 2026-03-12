#!/bin/bash
set -e

# Load environment variables
source ./env.sh

if [ "${RESUME,,}" == "true" ] && [ -f "/mnt/results/${BUCKET_PATH}/git_history.tar.gz" ]; then
    echo "Found existing experiment state. Resuming..."
    tar -xzf "/mnt/results/${BUCKET_PATH}/git_history.tar.gz" -C /app/ --no-same-owner --no-same-permissions
    git reset --hard HEAD
    cp "/mnt/results/${BUCKET_PATH}/results.tsv" /app/ 2>/dev/null || true
    echo "Resume complete."
else
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
