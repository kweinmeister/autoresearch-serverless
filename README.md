<div align="center">
  <h1>🚀 Serverless Autoresearch</h1>
  <p><strong>Fully Autonomous, Serverless AI Research Lab</strong></p>
  
  [![License: Apache 2.0](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](LICENSE)
  [![Cloud Run](https://img.shields.io/badge/Google%20Cloud-Cloud%20Run-4285F4?logo=googlecloud&logoColor=white)](#)
  [![Workflows](https://img.shields.io/badge/Google%20Cloud-Workflows-4285F4?logo=googlecloud&logoColor=white)](#)
  [![Gemini API](https://img.shields.io/badge/AI-Gemini%20Flash%20Lite-8E75B2?logo=googleai&logoColor=white)](#)
</div>

---

Deploy Andrej Karpathy's [AutoResearch](https://github.com/karpathy/autoresearch) natively on Google Cloud. This implementation enables you to run multi-day, endless architectural research studies leveraging the best of serverless infrastructure:

* **⚡ Compute:** NVIDIA L4 GPUs on Cloud Run Jobs (Serverless, pay-as-you-go).
* **🧠 Intelligence:** Gemini 3.1 Flash Lite API for high-quality, low-cost reasoning.
* **💾 Storage:** GCS FUSE mapping Cloud Storage as a persistent "memory" volume.
* **🚂 Orchestration:** Google Cloud Workflows to chain 1-hour container tasks into endless 24/7 research studies.

---

## ⏱️ The 1-Hour GPU Constraint

Cloud Run Jobs utilizing GPUs currently have a **1-hour task timeout**. A **Checkpoint & Resume** architecture is used to enable multi-hour research studies:

1. **Syncing:** A post-hook (`sync.sh`) backs up the workspace state to Cloud Storage after every experiment.
2. **Resuming:** On startup, `init.sh` automatically reconstructs the research environment from the latest snapshot.
3. **Chaining:** The included [Cloud Workflow](workflow.yaml) seamlessly triggers a new job immediately after the previous one hits its 1-hour timeout.

> [!TIP]
> **Need longer tasks?** Join the waitlist for long-running GPU jobs (up to 6 hours) here: [Google Cloud Waitlist](https://forms.gle/jHoqnwPbsF6uwKru5)

---

## 🏗️ 1. Environment Setup

Configure your Google Cloud environment:

```bash
export PROJECT_ID=$(gcloud config get-value project)
export REPO_NAME="autoresearch-repo"
export CLOUD_STORAGE_BUCKET="<your-gcs-bucket-name>" # Update this
export BUCKET_RESULTS_DIR="autoresearch-results"
export GEMINI_API_KEY="<YOUR_API_KEY>" # Update this
export SA_NAME="autoresearch-sa"

gcloud services enable \
    artifactregistry.googleapis.com \
    workflows.googleapis.com \
    run.googleapis.com \
    secretmanager.googleapis.com
```

Create a dedicated service account and store your Gemini API key in Secret Manager:

```bash
PROJECT_NUMBER=$(gcloud projects describe ${PROJECT_ID} --format="value(projectNumber)")
SA_EMAIL="${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"

# Create a dedicated service account
gcloud iam service-accounts create ${SA_NAME} \
  --display-name="Autoresearch Agent SA"

# Store the API key in Secret Manager and grant access
echo -n "${GEMINI_API_KEY}" | gcloud secrets create gemini-api-key --data-file=-

gcloud secrets add-iam-policy-binding gemini-api-key \
  --member="serviceAccount:${SA_EMAIL}" \
  --role="roles/secretmanager.secretAccessor"
```

Grant the service account permissions to manage Cloud Run jobs and access storage:

```bash
gcloud projects add-iam-policy-binding ${PROJECT_ID} \
  --member="serviceAccount:${SA_EMAIL}" \
  --role="roles/run.developer" --condition=None

gcloud iam service-accounts add-iam-policy-binding ${SA_EMAIL} \
  --member="serviceAccount:${SA_EMAIL}" \
  --role="roles/iam.serviceAccountUser" --project=${PROJECT_ID}
```

---

## 📂 2. Prepare & Build

Clone `autoresearch` and copy our serverless components into the root.

```bash
git clone https://github.com/karpathy/autoresearch.git
cd autoresearch
cp ../Dockerfile ../init.sh ../env.sh ../sync.sh ../workflow.yaml .
```

Submit the container build to Google Cloud Artifact Registry. This will pre-download the PyTorch image and prepare the ML dataset:

> **Customizing the prompt:** The agent's instructions are hardcoded in the `CMD` line of the `Dockerfile`. To change what the agent focuses on, edit the `--prompt` value and rebuild.

```bash
gcloud builds submit --tag us-central1-docker.pkg.dev/${PROJECT_ID}/${REPO_NAME}/autoresearch-job .
```

---

## 🚀 3. Deploy & Execute

### The Cloud Run Job

Create the job template with an L4 GPU enabled:

```bash
gcloud run jobs create autoresearch-job \
  --image us-central1-docker.pkg.dev/${PROJECT_ID}/${REPO_NAME}/autoresearch-job \
  --service-account ${SA_EMAIL} \
  --execution-environment gen2 \
  --cpu 4 --memory 16Gi --gpu 1 --gpu-type nvidia-l4 \
  --no-gpu-zonal-redundancy \
  --set-secrets="GEMINI_API_KEY=gemini-api-key:latest" \
  --set-env-vars="BUCKET_RESULTS_DIR=${BUCKET_RESULTS_DIR}" \
  --add-volume=name=results-vol,type=cloud-storage,bucket=${CLOUD_STORAGE_BUCKET} \
  --add-volume-mount=volume=results-vol,mount-path=/mnt/results \
  --max-retries 0 --task-timeout 1h --region us-central1
```

### The Autonomous Workflow (Recommended)

Deploy our orchestration system (contained in [`workflow.yaml`](workflow.yaml)) to manage multi-hour looping.

```bash
# Register the Workflow definition
gcloud workflows deploy autoresearch-study \
  --source=workflow.yaml \
  --location=us-central1 \
  --set-env-vars CLOUD_STORAGE_BUCKET=${CLOUD_STORAGE_BUCKET}

# Execute a 24-hour study
gcloud workflows execute autoresearch-study \
  --location=us-central1 \
  --data='{"hours": 24}'
```

---

## 📊 4. Analyze Results

Your progress and metrics sync regularly to `gs://${CLOUD_STORAGE_BUCKET}/${BUCKET_RESULTS_DIR}/`.

* **`results.tsv`**: Master ledger of valid hyperparameter mutations and scores.
* **`train.py`**: The latest, "best" code configuration tested.
* **`api_tokens.jsonl`**: LLM usage and tracking logs per-experiment.
* **`run.log`**: Console snapshot of the active training loop.

---

## 🔒 Security Considerations

This project runs an **autonomous AI agent** with `--yolo` mode, which executes shell commands without user confirmation. Please be aware of the following:

* **Autonomous Execution:** The Gemini CLI `--yolo` flag grants the agent unrestricted code execution privileges inside the container. This is required for unattended operation, but means the agent can install packages, make network requests, and modify any file in the workspace.
* **Sandboxed Environment:** The `gen2` execution environment uses [gVisor](https://gvisor.dev/) for kernel-level container sandboxing, providing defense-in-depth against container escapes.
* **GCS Trust Boundary:** The GCS bucket stores experiment state (code, git history, logs) that is restored on resume. Ensure your bucket has appropriate [IAM controls](https://cloud.google.com/storage/docs/access-control/iam) to prevent unauthorized writes.
* **Dedicated Service Account:** This setup uses a purpose-built service account (`autoresearch-sa`) rather than the default compute service account, following the principle of least privilege.

---

## 🤝 Contributing

Issues and Pull Requests are welcome!

## 📄 License

This project is licensed under the Apache 2.0 License - see the [LICENSE](LICENSE) file for details.
