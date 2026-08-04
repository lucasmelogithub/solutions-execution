# Attendee Instructions — From Zero to Xeon (vLLM edition)

Welcome! Follow these steps **in order**. If you get stuck for more than 2 minutes, **raise your hand** — do not silently fall behind.

> Everything in this workshop runs from **Windows PowerShell**. When you see a gray box with commands, copy/paste it into PowerShell.

---

## 0. Setup (15 minutes)

You will install **5 tools**. We give you two paths — pick **one**:

- **Path A — Automated (recommended, ~5 minutes):** one PowerShell script installs everything via `winget`.
- **Path B — Manual (~10 minutes):** click each download link, run each installer. Use this if `winget` is blocked on your machine.

### 0.1 Open PowerShell

Press the `Windows` key, type `powershell`, press Enter. A blue window opens. Leave it open.

---

### 0.2 Pick **one**: Path A or Path B

#### Path A — Automated install (recommended)

Copy/paste this entire block into PowerShell and press Enter:

```powershell
# 1. Install Git first (the script needs it to clone the repo)
winget install --id Git.Git --exact --silent --accept-package-agreements --accept-source-agreements
```

**Close PowerShell, open a new one** (so `git` is on your `PATH`), then:

```powershell
cd $HOME
git clone https://github.com/lucasmelogithub/solutions-execution.git
cd solutions-execution\workshop\cloud-workshop
.\prereqs\install-tools.ps1
```

The script installs: VSCode, AWS CLI, Google Cloud SDK, Terraform. It takes ~5 minutes. **Skip to step 0.3 when it finishes.**

---

#### Path B — Manual install (use only if winget is blocked)

Install these **in order**. For each one: click the link, download the **64-bit Windows installer**, run it, click **Next → Next → Install** with the default options.

| # | Tool | Download link | What to install |
|---|------|---------------|------------------|
| 1 | **Git** | <https://git-scm.com/download/win> | "64-bit Git for Windows Setup" |
| 2 | **Visual Studio Code** | <https://code.visualstudio.com/Download> | "Windows" → "User Installer" 64-bit. **On the "Select Additional Tasks" screen, tick "Add to PATH"** |
| 3 | **AWS CLI v2** | <https://awscli.amazonaws.com/AWSCLIV2.msi> | Direct MSI download — just run it |
| 4 | **Google Cloud SDK (gcloud)** | <https://dl.google.com/dl/cloudsdk/channels/rapid/GoogleCloudSDKInstaller.exe> | Direct EXE — accept all defaults; let it run `gcloud init` at the end (or skip and run it later) |
| 5 | **Terraform** | <https://developer.hashicorp.com/terraform/install> | "Windows / AMD64" zip → unzip → put `terraform.exe` somewhere on your `PATH` (easiest: `C:\Windows\System32\terraform.exe`) |

After all 5 are installed, **close PowerShell and open a new one** (PowerShell only sees new tools after a restart). Then clone the workshop repo:

```powershell
cd $HOME
git clone https://github.com/lucasmelogithub/solutions-execution.git
cd solutions-execution\workshop\cloud-workshop
```

---

### 0.3 Verify everything is installed

From the `cloud-workshop` folder run:

```powershell
.\prereqs\verify-tools.ps1
```

You should see green `[ OK ]` next to `git`, `code`, `aws`, `gcloud`, `terraform`. If any line is red `[FAIL]` — **raise your hand**.

> First time running a `.ps1` file? If PowerShell complains about "execution policy", run this once and try again:
>
> ```powershell
> Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
> ```

### 0.4 Open the project in VSCode

```powershell
code .
```

VSCode will open. In the top menu choose **Terminal → New Terminal**. That terminal is also PowerShell — use it for the rest of the workshop.

### 0.5 Sign in to the two clouds

You will receive a **handout** with sandbox credentials. Run these and follow the prompts:

```powershell
# AWS — paste the Access Key, Secret, region (us-east-1), output (json)
aws configure

# GCP — opens a browser, sign in with the workshop Google account
gcloud auth login
gcloud config set project <project-id-from-handout>

# GCP — ALSO required: Application Default Credentials, which Terraform uses
gcloud auth application-default login
```

> Why two `gcloud` logins? The first authenticates the **`gcloud` CLI**. The second writes Application Default Credentials to disk, which **Terraform's google provider** reads. Skip it and Module 2 will fail with `could not find default credentials`.

### 0.6 Pick your unique name prefix

Pick a **6-character lowercase prefix** that nobody else will pick. Use your initials + 3 digits, for example `lmm042`. **Write it down.** You will type it twice today.

---

## Module 1 — vLLM on AWS Xeon 6 with AMX (50 minutes)

**Goal:** deploy a single AWS EC2 `m8i.4xlarge` (Xeon 6 with **AMX**, 16 vCPU, 64 GB DDR5). Run [vLLM v0.21.0](https://github.com/vllm-project/vllm) via its pre-built Docker image — it downloads models directly from HuggingFace, serves an OpenAI-compatible API, and can light up the **AMX** matrix tiles for accelerated prefill. Serve the model behind [Open WebUI](https://docs.openwebui.com/) and chat with it in your browser. Then swap in different models — including **Qwen3 MoE** — to compare performance.

### 1.1 Move into the module folder

```powershell
cd terraform-aws
```

### 1.2 Create your `terraform.tfvars`

```powershell
Copy-Item terraform.tfvars.example terraform.tfvars
code terraform.tfvars
```

In VSCode, change `name_prefix = "changeme"` to your prefix from step 0.6. Save the file (`Ctrl+S`).

### 1.3 Deploy

```powershell
terraform init
terraform plan
terraform apply -auto-approve
```

`apply` takes ~2 minutes. When it finishes Terraform prints outputs including `public_ip`, `webui_url`, and `ssh_command`.

### 1.4 SSH into the instance

```powershell
ssh -F ssh_config vm
```

> Off Intel's network? Use `ssh_config_no_proxy` instead.

You are now logged into an Ubuntu box running on Xeon 6. The shell prompt looks like `ubuntu@ip-...`.

### 1.5 Install Docker and set your HuggingFace token

We run vLLM and Open WebUI as Docker containers — no Python venvs or system packages to manage.

```bash
# 1. Install Docker and jq (JSON tool used later for parsing API responses)
sudo apt-get update -qq && sudo apt-get install -y docker.io jq
```

```bash
# 2. Allow your user to run Docker without sudo
sudo usermod -aG docker $USER && newgrp docker
```

```bash
# 3. Verify Docker is working
docker --version
```

```bash
# 4. Set HuggingFace token for higher rate limits and faster downloads
export HF_TOKEN=<your-token-from-handout>
```

> Your instructor will provide the `HF_TOKEN` value. A token avoids HuggingFace's anonymous rate limits (which throttle large model downloads). If you have your own HuggingFace account, you can create a token at <https://huggingface.co/settings/tokens> (read-only access is sufficient).

### 1.6 Start vLLM with the Granite MoE model

```bash
# Start vLLM (first run downloads the model — takes a few minutes)
docker run -d --name vllm \
  --network host \
  --cap-add SYS_NICE \
  --security-opt seccomp=unconfined \
  -v /home/ubuntu/.cache/huggingface:/root/.cache/huggingface \
  -e HF_TOKEN=$HF_TOKEN \
  -e VLLM_CPU_KVCACHE_SPACE=40 \
  -e VLLM_CPU_OMP_THREADS_BIND=auto \
  -e VLLM_CPU_NUM_OF_RESERVED_CPU=1 \
  -e VLLM_CPU_SGL_KERNEL=1 \
  vllm/vllm-openai-cpu:v0.21.0-x86_64 \
  --model ibm-granite/granite-3.1-3b-a800m-instruct \
  --dtype bfloat16 \
  --host 127.0.0.1 --port 8000 \
  --max-model-len 4096

echo "vLLM starting... (first run downloads model weights)"
until curl -fs http://127.0.0.1:8000/health > /dev/null 2>&1; do echo "waiting for vLLM..."; docker logs --tail 4 vllm 2>/dev/null; sleep 5; done
echo "vLLM is up and serving!"
```

> **What do the environment variables do?**
>
> | Variable | Purpose |
> |---|---|
> | `VLLM_CPU_KVCACHE_SPACE=40` | KV cache size in GiB (64 GB machine, ~6.6 GB model) |
> | `VLLM_CPU_OMP_THREADS_BIND=auto` | Auto-bind one thread per physical core (recommended) |
> | `VLLM_CPU_NUM_OF_RESERVED_CPU=1` | Reserve 1 core for the serving framework |
> | `VLLM_CPU_SGL_KERNEL=1` | Enable AMX-optimized small-batch kernels (experimental) |
>
> **What is `VLLM_CPU_SGL_KERNEL`?** This experimental flag enables AMX-optimized small-batch kernels for linear and MoE layers. It requires AMX ISA, BFloat16 weights, and weight shapes divisible by 32. This is vLLM's equivalent of llama.cpp's `GGML_AMX=ON`.

> **Docker flags explained:** `--network host` shares the host network stack (simplest setup — vLLM listens directly on `127.0.0.1:8000`). `--cap-add SYS_NICE` and `--security-opt seccomp=unconfined` enable NUMA-aware thread scheduling for optimal CPU performance.

> Verify the model loaded: `curl -s http://127.0.0.1:8000/v1/models | jq '.data[].id'`. You should see `ibm-granite/granite-3.1-3b-a800m-instruct`.

### 1.7 Start Open WebUI

```bash
docker run -d --name owui \
  --network host \
  -e ENABLE_OLLAMA_API=false \
  -e OPENAI_API_BASE_URLS="http://localhost:8000/v1" \
  -e OPENAI_API_KEYS="no-key" \
  -e ENABLE_OPENAI_API_STREAM_OPTIONS=true \
  ghcr.io/open-webui/open-webui:main

until curl -fs http://127.0.0.1:8080 > /dev/null; do echo "waiting for Open WebUI..."; sleep 5; done
echo "Open WebUI is up."
```

### 1.8 Open the chat in your browser

Back in your **PowerShell terminal**, print the URL:

```powershell
terraform output webui_url
```

Open it in a browser tab.

> First visit prompts you to **create a local admin account**. Use a throwaway like `admin@intel.com` / `intel123` — this box lives for ~90 minutes and the security group only accepts traffic from Intel CIDRs.

After login:

1. Click the model selector at the top.
2. Pick the model shown (e.g. `ibm-granite/granite-3.1-3b-a800m-instruct`).
3. Start chatting! Try these prompts:

#### Prompt 1 — Technical (computer architecture)

> Explain in detail how a modern x86 CPU executes a single instruction, end to end: instruction fetch, decode, register rename, dispatch, out-of-order execution, the role of the memory hierarchy (L1/L2/L3 cache, TLB, store buffer), retirement, and how branch prediction and speculative execution affect throughput. Aim for at least 600 words and use clear headings.

#### Prompt 2 — Creative (long-form story)

> Write an 800-word short story set in 100 AD about a Roman aqueduct engineer named Lucius who unearths a mysterious mechanical artifact beneath the Forum while inspecting a damaged conduit. Include character dialogue, sensory description of the underground passages, and a clear three-act structure ending with an unsettling discovery.

#### Prompt 3 — Comparative (deep technical comparison)

> Compare TCP and UDP in depth — protocol design, header field layouts, connection setup and teardown, reliability, ordering, flow control, congestion control mechanisms (Reno, CUBIC, BBR), latency and throughput trade-offs, and at least four real-world applications where one is preferred over the other (such as video conferencing, file transfer, gaming, DNS, and live streaming). Aim for at least 700 words and structure it with headings.

Open WebUI shows an **ℹ️ info button** (small `i` icon) in the action bar below each completed answer — click it to see token usage details.

### 1.9 Measure prefill and decode speed directly

To get precise performance numbers, use the vLLM OpenAI-compatible API directly from your SSH session:

```bash
curl -s http://127.0.0.1:8000/v1/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "ibm-granite/granite-3.1-3b-a800m-instruct",
    "prompt": "Compare TCP and UDP in depth: protocol design, headers, reliability, congestion control, four real-world applications. 700+ words.",
    "max_tokens": 300,
    "stream": false
  }' | jq '{
    prompt_tokens: .usage.prompt_tokens,
    gen_tokens: .usage.completion_tokens,
    total_tokens: .usage.total_tokens
  }'
```

You should see output like:

```json
{
  "prompt_tokens": 38,
  "gen_tokens": 300,
  "total_tokens": 338
}
```

For detailed timing, check vLLM's built-in metrics endpoint:

```bash
curl -s http://127.0.0.1:8000/metrics | grep -E "vllm:(prompt|generation)_tokens_total|time_to_first_token|time_per_output_token" | head -10
```

| Metric | What it measures | Bottleneck |
|---|---|---|
| Time to first token (TTFT) | How fast the model digests the prompt before generating | **Compute-bound** — this is where AMX matrix tiles dominate |
| Time per output token (TPOT) | How fast the model generates each output token | **Memory-bandwidth bound** — DDR5 on Xeon 6 helps here |

Both numbers benefit from the Xeon 6 architecture. TTFT is the key AMX metric — in production workloads with long prompts or batched requests, prefill speed dominates total latency.

### 1.10 Try other models — Qwen3 MoE and more

One of vLLM's strengths is easy model swapping. Stop the current container and start a new one with a different model.

#### Option A — Qwen3.5-4B (dense, BF16, ~8 GB)

A fast dense model that fits easily on this machine.

```bash
# 1. Stop and remove the current vLLM container
docker stop vllm && docker rm vllm
```

```bash
# 2. Start vLLM with Qwen3.5-4B (first run downloads ~8 GB)
docker run -d --name vllm \
  --network host \
  --cap-add SYS_NICE \
  --security-opt seccomp=unconfined \
  -v /home/ubuntu/.cache/huggingface:/root/.cache/huggingface \
  -e HF_TOKEN=$HF_TOKEN \
  -e VLLM_CPU_KVCACHE_SPACE=40 \
  -e VLLM_CPU_OMP_THREADS_BIND=auto \
  -e VLLM_CPU_NUM_OF_RESERVED_CPU=1 \
  -e VLLM_CPU_SGL_KERNEL=1 \
  vllm/vllm-openai-cpu:v0.21.0-x86_64 \
  --model Qwen/Qwen3.5-4B \
  --dtype bfloat16 \
  --host 127.0.0.1 --port 8000 \
  --max-model-len 4096

until curl -fs http://127.0.0.1:8000/health > /dev/null 2>&1; do echo "waiting for vLLM..."; docker logs --tail 2 vllm 2>/dev/null; sleep 5; done
echo "Qwen3.5-4B is ready!"
```

Refresh Open WebUI in your browser — the model selector will now show `Qwen/Qwen3.5-4B`. Chat and compare the quality and speed against Granite.

#### Option B — Qwen3-30B-A3B MoE (AWQ INT4, ~15 GB)

This is the **Qwen3 Mixture-of-Experts** model: 30.5B total parameters with 128 experts, but only 3.3B active per token. The full BF16 model is ~61 GB and won't fit on a 64 GB machine, so we use an **AWQ INT4 quantized** version that compresses to ~15 GB.

```bash
# 1. Stop and remove the current vLLM container
docker stop vllm && docker rm vllm
```

```bash
# 2. Start vLLM with Qwen3-30B-A3B AWQ (first run downloads ~15 GB)
# NOTE: KV cache reduced to 10 GB to leave room for the larger model
# NOTE: VLLM_CPU_SGL_KERNEL is NOT set — AMX SGL kernels require BF16 weights
docker run -d --name vllm \
  --network host \
  --cap-add SYS_NICE \
  --security-opt seccomp=unconfined \
  -v /home/ubuntu/.cache/huggingface:/root/.cache/huggingface \
  -e HF_TOKEN=$HF_TOKEN \
  -e VLLM_CPU_KVCACHE_SPACE=10 \
  -e VLLM_CPU_OMP_THREADS_BIND=auto \
  -e VLLM_CPU_NUM_OF_RESERVED_CPU=1 \
  vllm/vllm-openai-cpu:v0.21.0-x86_64 \
  --model QuixiAI/Qwen3-30B-A3B-AWQ \
  --dtype auto \
  --quantization awq \
  --host 127.0.0.1 --port 8000 \
  --max-model-len 4096

until curl -fs http://127.0.0.1:8000/health > /dev/null 2>&1; do echo "waiting for vLLM..."; docker logs --tail 2 vllm 2>/dev/null; sleep 5; done
echo "Qwen3-30B-A3B (AWQ) is ready!"
```

> **Why AWQ and not BF16?** The Qwen3-30B-A3B model has 30.5B total parameters across 128 experts. At BF16 (2 bytes/param) that's ~61 GB — the full model won't fit in 64 GB RAM alongside the KV cache. AWQ INT4 quantization compresses the weights to ~15 GB, making it runnable on this instance.

> **Why no `VLLM_CPU_SGL_KERNEL`?** The AMX-optimized SGL kernels require BFloat16 weight types. Since AWQ stores weights in INT4, the AMX kernels cannot be used. The model still runs on CPU — just without the AMX matrix tile acceleration.

Refresh Open WebUI — the model selector will now show `QuixiAI/Qwen3-30B-A3B-AWQ`. This MoE model is significantly more capable but slower on CPU due to the larger weight set. Try the same prompts and compare answer quality.

#### Option C — Switch back to Granite

```bash
docker stop vllm && docker rm vllm

docker run -d --name vllm \
  --network host \
  --cap-add SYS_NICE \
  --security-opt seccomp=unconfined \
  -v /home/ubuntu/.cache/huggingface:/root/.cache/huggingface \
  -e HF_TOKEN=$HF_TOKEN \
  -e VLLM_CPU_KVCACHE_SPACE=40 \
  -e VLLM_CPU_OMP_THREADS_BIND=auto \
  -e VLLM_CPU_NUM_OF_RESERVED_CPU=1 \
  -e VLLM_CPU_SGL_KERNEL=1 \
  vllm/vllm-openai-cpu:v0.21.0-x86_64 \
  --model ibm-granite/granite-3.1-3b-a800m-instruct \
  --dtype bfloat16 \
  --host 127.0.0.1 --port 8000 \
  --max-model-len 4096

until curl -fs http://127.0.0.1:8000/health > /dev/null 2>&1; do echo "waiting for vLLM..."; docker logs --tail 2 vllm 2>/dev/null; sleep 5; done
echo "Back to Granite!"
```

#### Model comparison summary

| Model | Type | Size (RAM) | AMX Kernels | KV Cache | Best for |
|---|---|---|---|---|---|
| `ibm-granite/granite-3.1-3b-a800m-instruct` | MoE (BF16) | ~6.6 GB | Yes | 40 GB | Fast inference, AMX demo |
| `Qwen/Qwen3.5-4B` | Dense (BF16) | ~8 GB | Yes | 40 GB | Quality vs. speed comparison |
| `QuixiAI/Qwen3-30B-A3B-AWQ` | MoE (AWQ INT4) | ~15 GB | No | 10 GB | Large MoE quality, 128 experts |

### 1.11 Leave the instance running for now

We will destroy everything at the end together.

---

## Module 2 — Deploy a GCP VM and find Intel AMX (30 minutes)

**Goal:** deploy what looks like a "small GCP VM", discover it has no AMX, change **one variable**, redeploy, confirm AMX is now present.

### 2.1 Move into the module folder

```powershell
cd ..\terraform-gcp
```

### 2.2 Create your `terraform.tfvars`

```powershell
Copy-Item terraform.tfvars.example terraform.tfvars
code terraform.tfvars
```

Set your `name_prefix`. **Paste the `project_id`** from your handout. **Leave `machine_type` set to `c4a-standard-2` for now.** Save.

> `c4a` is GCP's Axion family — **ARM CPUs**. Looks innocent. Not Intel.

### 2.3 Deploy and SSH in

```powershell
terraform init
terraform apply -auto-approve
```

When it finishes, Terraform creates an SSH keypair (`tfkey` / `tfkey.pub`) and an `ssh_config` file in this folder, with the Intel proxy already wired up. Connect:

```powershell
ssh -F ssh_config vm
```

> If you're off Intel's network, use `ssh -F ssh_config_no_proxy vm` instead.

### 2.4 Look for AMX (it won't be there)

Inside the VM:

```bash
lscpu | grep -i "model name\|architecture"
grep -o 'amx[a-z_]*' /proc/cpuinfo | sort -u
```

`Architecture: aarch64`. The `grep` for `amx` returns **nothing**. **This is the teaching moment** — the customer asked for "a small cloud VM" and got an ARM box. AMX lives on **Intel Xeon**, not on ARM.

Exit the VM (`exit`).

### 2.5 Change ONE variable and redeploy

```powershell
code terraform.tfvars
```

Change:

```hcl
machine_type = "c4a-standard-2"
```

to:

```hcl
machine_type = "c4-standard-4-lssd"
```

Save. Re-apply:

```powershell
terraform apply -auto-approve
```

Terraform will **destroy the ARM VM and create a Xeon 6 VM** — you'll see `1 to destroy, 1 to add` in the plan.

### 2.6 SSH in and confirm AMX is present

```powershell
ssh -F ssh_config vm
```

Inside the VM:

```bash
lscpu | grep -i "model name\|architecture"
grep -o 'amx[a-z_]*' /proc/cpuinfo | sort -u
```

`Architecture: x86_64`, `Model name: Intel(R) Xeon(R) ...`, and the `grep` now prints **`amx_bf16`, `amx_int8`, `amx_tile`**. AMX is here.

> _Instructor will hand out the deeper AMX validation steps for the curious._

Exit (`exit`). Move on.

---

## Teardown (10 minutes) — DO NOT SKIP

If you skip this, the sandbox keeps billing. Run **both** of these from the `cloud-workshop` folder:

```powershell
cd $HOME\solutions-execution\workshop\cloud-workshop\terraform-gcp
terraform destroy -auto-approve

cd ..\terraform-aws
terraform destroy -auto-approve
```

Each `destroy` ends with `Destroy complete!`. **Show your screen to a workshop assistant before you leave.**

---

## You did it

In 2 hours you:

- Installed and used VSCode, Git, two cloud CLIs, and Terraform.
- Deployed an AWS EC2 Xeon 6 instance, ran **vLLM v0.21.0** via its pre-built Docker image with AMX-optimized kernels, and **ran a real GenAI workload accelerated by Intel AMX**.
- Tested **multiple models** — including IBM Granite MoE, Qwen3.5 dense, and Qwen3-30B-A3B MoE (AWQ quantized) — all on the same CPU instance.
- Proved Intel AMX is present on GCP Xeon 6 (and absent on ARM).
- Tore it all down.

That's the entire loop a customer goes through when they evaluate Intel-on-cloud. Now you can demo it.

---

## Appendix — If something goes wrong

The issues you are most likely to hit, with the exact one-liner that fixes each. **Raise your hand** if a fix below doesn't unblock you within 2 minutes.

| You see | What it means | What to do |
|---|---|---|
| `winget : The term 'winget' is not recognized` | Old Windows / IT disabled App Installer | Use **Path B** (manual installers) in step 0.2 |
| `cannot be loaded because running scripts is disabled on this system` | PowerShell execution policy | Run `Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned`, then retry |
| `git` / `terraform` / `code` / `gcloud` `not recognized` right after install | PowerShell PATH is cached | **Close PowerShell, open a new one**, retry |
| Module 1 `terraform apply` → `InsufficientInstanceCapacity` for `m8i.4xlarge` | Region/AZ ran out of `m8i` capacity | **Raise your hand** — instructor will switch the region |
| Module 1 `ssh -F ssh_config vm` → "Connection refused" | Instance still booting (sshd not up yet) | Wait ~30s and retry |
| Module 1 SSH → hangs at `connecting...` forever | `ssh_config` uses Intel proxy; you're off Intel network | Use `ssh_config_no_proxy` instead |
| Module 1 `docker: permission denied` | Docker group membership not active | Run `newgrp docker` or log out and SSH back in |
| Module 1 vLLM download looks frozen | First-time download from HuggingFace — large model | Be patient; if it errors, run `docker stop vllm && docker rm vllm` and re-run the `docker run` command (it resumes via the cached volume) |
| Module 1 vLLM download → `401 Unauthorized` or rate-limited | `HF_TOKEN` not set or expired | Re-run `export HF_TOKEN=<token>` from step 1.5, then stop/rm/re-run the container |
| Module 1 vLLM crashes with `OOM` or `Cannot allocate memory` | KV cache + model too large for 64 GB | Reduce `VLLM_CPU_KVCACHE_SPACE` to `20` in the `docker run` command and restart |
| Module 1 Open WebUI model dropdown empty | vLLM container not running or crashed | Run `docker ps` to check; if not running, check `docker logs vllm` for errors |
| Module 1 browser → `ERR_CONNECTION_REFUSED` on `:8080` | Open WebUI hasn't finished starting | Wait 30s; run `docker logs owui` to confirm it's up |
| Module 2 `terraform apply` → `google: could not find default credentials` | Forgot the second `gcloud` login | Run `gcloud auth application-default login`, then `terraform apply` again |
| Module 2 `terraform apply` → `network 'default' not found` | Project has no default VPC | **Raise your hand** — instructor needs to create it |
| Module 2 SSH → hangs at `connecting...` forever | `ssh_config` uses Intel proxy; you're off Intel network | `ssh -F ssh_config_no_proxy vm` |
| `terraform destroy` says `Error: ... still in use` | A previous `apply` was interrupted | Re-run `terraform destroy -auto-approve` once more; it usually clears |

When in doubt: from the `cloud-workshop` folder, run `.\prereqs\verify-tools.ps1` again — it confirms every tool is present and on PATH.
