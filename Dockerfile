# Use a recent official PyTorch image with CUDA support
FROM pytorch/pytorch:2.9.1-cuda12.8-cudnn9-runtime

# Install system dependencies (Node.js for Gemini CLI, gcc for torch.compile)
RUN apt-get update && apt-get install -y curl git ca-certificates procps gcc && \
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
    apt-get install -y nodejs && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Configure git for the autonomous agent
RUN git config --global user.email "agent@autoresearch.local" \
    && git config --global user.name "Autoresearch Agent" \
    && git config --global init.defaultBranch master

# Create a non-root user for the autonomous agent
RUN useradd -m -s /bin/bash researcher

# Install uv for fast Python package management (pinned version)
RUN curl -LsSf https://astral.sh/uv/0.6.6/install.sh | sh
ENV PATH="/root/.local/bin:$PATH"

WORKDIR /app

# Copy dependency manifest first for layer caching
COPY pyproject.toml uv.lock ./
RUN uv sync

# Copy the rest of the source
COPY . /app
RUN chmod +x sync.sh init.sh env.sh && chown -R researcher:researcher /app

# Patch the agent's instructions to run our sync script after every experiment
RUN sed -i 's|uv run train.py > run.log 2>&1|&; ./sync.sh|g' program.md

# Pre-tune the batch size for NVIDIA L4 GPUs to avoid initial OOM troubleshooting
RUN sed -i 's/DEVICE_BATCH_SIZE = 128/DEVICE_BATCH_SIZE = 16/g' train.py

# Add a guardrail to program.md to prevent the agent from gaming the random seed
RUN echo "\nCRITICAL: Do not modify the random seed in train.py. All improvements must come from architecture or hyperparameter changes." >> program.md

# Patch program.md to avoid missing "cat" in bash heredocs (prevents <<EOF parsing errors)
RUN echo "\nCRITICAL: When writing files using heredocs, always prepend 'cat' (e.g., 'cat <<EOF > filename' instead of '<<EOF')." >> program.md

# Patch program.md to remove the interactive confirmation step
RUN sed -i 's/Once you get confirmation, kick off the experimentation./Do NOT ask for confirmation. Immediately kick off the experimentation LOOP FOREVER./g' program.md

# Prepare data
RUN uv run prepare.py

# Install Gemini CLI globally
RUN npm install -g @google/gemini-cli

# Switch to non-root user
USER researcher
ENV HOME=/home/researcher

# Start the agent in fully autonomous headless mode
CMD ./init.sh && gemini \
    --prompt "Hi have a look at program.md and let's kick off a new experiment!" \
    --yolo \
    --model gemini-3.1-flash-lite-preview
