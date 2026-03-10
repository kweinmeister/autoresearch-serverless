#!/bin/bash
source ./env.sh
echo "Syncing results to GCS..."
mkdir -p "/mnt/results/${BUCKET_PATH}"
# Use atomic writes (write to tmp then move) to avoid GCS FUSE "legacy staged writes" logs
cp results.tsv "/mnt/results/${BUCKET_PATH}/results.tsv.tmp" && mv "/mnt/results/${BUCKET_PATH}/results.tsv.tmp" "/mnt/results/${BUCKET_PATH}/results.tsv"
cp train.py "/mnt/results/${BUCKET_PATH}/train.py.tmp" && mv "/mnt/results/${BUCKET_PATH}/train.py.tmp" "/mnt/results/${BUCKET_PATH}/train.py"
cp run.log "/mnt/results/${BUCKET_PATH}/run.log.tmp" && mv "/mnt/results/${BUCKET_PATH}/run.log.tmp" "/mnt/results/${BUCKET_PATH}/run.log"

tar -czf "/mnt/results/${BUCKET_PATH}/git_history.tar.gz.tmp" .git/ 2>/dev/null && mv "/mnt/results/${BUCKET_PATH}/git_history.tar.gz.tmp" "/mnt/results/${BUCKET_PATH}/git_history.tar.gz"

# Parse the Gemini CLI session log to record cumulative token usage
python3 -c "
import json, glob, os
files = glob.glob('/root/.gemini/**/chats/session-*.json', recursive=True)
if files:
    latest = max(files, key=os.path.getctime)
    with open(latest) as f:
        data = json.load(f)
    totals = {'input': 0, 'cached': 0, 'output': 0}
    # Prefer stats summary (has output tokens), fall back to per-message sums
    stats = data.get('stats', {}).get('models', {})
    if stats:
        for model_data in stats.values():
            t = model_data.get('tokens', {})
            totals['input'] += t.get('input', t.get('prompt', 0))
            totals['cached'] += t.get('cached', 0)
            totals['output'] += t.get('candidates', 0)
    else:
        msgs = data.get('messages', [])
        for x in msgs:
            t = x.get('tokens', {})
            totals['input'] += t.get('input', 0)
            totals['cached'] += t.get('cached', 0)
            totals['output'] += t.get('output', 0)
    totals['session'] = os.path.basename(latest)
    print(json.dumps(totals))
" > /tmp/api_tokens_latest.jsonl 2>/dev/null || true
# Append locally, then atomic-move the full file to GCS
if [ -f /tmp/api_tokens_latest.jsonl ] && [ -s /tmp/api_tokens_latest.jsonl ]; then
    cat /tmp/api_tokens_latest.jsonl >> /tmp/api_tokens_all.jsonl
    cp /tmp/api_tokens_all.jsonl "/mnt/results/${BUCKET_PATH}/api_tokens.jsonl.tmp" && \
    rm -f "/mnt/results/${BUCKET_PATH}/api_tokens.jsonl" && \
    mv "/mnt/results/${BUCKET_PATH}/api_tokens.jsonl.tmp" "/mnt/results/${BUCKET_PATH}/api_tokens.jsonl"
fi
