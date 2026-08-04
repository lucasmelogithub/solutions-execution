# Attendee Instructions — From Zero to Xeon

Welcome! Follow these steps **in order**. If you get stuck for more than 2 minutes, **raise your hand** — do not silently fall behind.

> Everything in this workshop runs from **Windows PowerShell**. When you see a gray box with commands, copy/paste it into PowerShell.

---

## 0. Setup (15 minutes)

### Cloud Account Access

> **[TBD — Intel AGS links will be provided by your instructor on the day of the workshop]**
>
> You will receive links via **Intel AGS** to request access to your cloud accounts (AWS & GCP) and portal login credentials. Do not proceed until you have received these from your instructor.

---

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
git clone https://github.com/OTCShare2/solutions-execution.git
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
git clone https://github.com/OTCShare2/solutions-execution.git
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

## Module 1 — Ollama on AWS Xeon 6 with AMX (50 minutes)

**Goal:** deploy a single AWS EC2 `m8i.4xlarge` (Xeon 6 with **AMX**, 16 vCPU, 64 GB DDR5). Install [Ollama](https://github.com/ollama/ollama) to download a model, then build [llama.cpp](https://github.com/ggml-org/llama.cpp) from source with **`GGML_AMX=ON`** so the inference engine lights up the Advanced Matrix Extensions hardware. Serve the model behind [Open WebUI](https://docs.openwebui.com/) and chat with it in your browser.

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

### 1.5 Install Ollama and pull the model

Ollama is used as a convenient model downloader. We will replace it with an AMX-enabled backend in the next step.

```bash
# 1. Install Ollama
curl -fsSL https://ollama.com/install.sh | sh
```

```bash
# 2. Wait for the Ollama daemon to finish starting
until curl -fs http://127.0.0.1:11434/api/tags > /dev/null; do echo "waiting for ollama..."; sleep 2; done
echo "Done"
```

```bash
# 3. Pull the model (~2 GB)
ollama pull granite3.1-moe:3b-instruct-q8_0
# ollama pull qwen3:30b-a3b-q4_K_M
# ollama pull qwen3:30b-a3b-q8_0
# ollama pull qwen3.5:35b-a3b-q8_0
# ollama pull qwen3.5:4b-q8_0
```

### 1.6 Build llama.cpp with AMX

Stock Ollama ships a pre-built `llama.cpp` binary that uses AVX-512 but **does not enable the `GGML_AMX` backend**. Building from source with `-DGGML_AMX=ON` lights up the AMX matrix tiles for GEMM operations, giving a significant speedup on compute-bound prefill.

```bash
# 1. Install build tools
sudo apt-get update -qq && sudo apt-get install -y build-essential cmake git
```

```bash
# 2. Clone and build llama.cpp with AMX (~5 minutes on 16 vCPU)
git clone https://github.com/ggml-org/llama.cpp.git ~/llama.cpp
cd ~/llama.cpp
cmake -B build -DGGML_AMX=ON -DGGML_NATIVE=ON -DCMAKE_BUILD_TYPE=Release
cmake --build build -j$(nproc) --target llama-server
cd ~
```

```bash
# 3. Copy the model from Ollama's blob store
GGUF_PATH=$(ollama show granite3.1-moe:3b-instruct-q8_0 --modelfile | grep '^FROM ' | awk '{print $2}')
echo "Ollama blob: $GGUF_PATH"
sudo cp "$GGUF_PATH" ~/model.gguf
sudo chown ubuntu:ubuntu ~/model.gguf
echo "Copied: $(ls -lh ~/model.gguf | awk '{print $5}')"
```

```bash
# 4. Stop Ollama, start llama-server with AMX
sudo systemctl stop ollama

nohup ~/llama.cpp/build/bin/llama-server \
  --model ~/model.gguf \
  --alias granite3.1-moe \
  --host 127.0.0.1 --port 8001 \
  --threads 16 --ctx-size 4096 \
  > ~/llama-server.log 2>&1 &

until curl -fs http://127.0.0.1:8001/health > /dev/null 2>&1; do echo "waiting for llama-server..."; sleep 2; done
echo "llama-server is up with AMX"
```

> Verify AMX is active: `grep 'AMX_INT8\|AMX_BF16\|REPACK' ~/llama-server.log`. You should see `AMX_INT8 = 1`.

### 1.7 Install and start Open WebUI

```bash
sudo apt-get install -y python3-venv jq
python3 -m venv ~/owui
source ~/owui/bin/activate
pip install --upgrade pip
pip install open-webui

export ENABLE_OLLAMA_API=false
export OPENAI_API_BASE_URLS="http://localhost:8001/v1"
export OPENAI_API_KEYS="no-key"
export ENABLE_OPENAI_API_STREAM_OPTIONS=true

nohup open-webui serve --host 0.0.0.0 --port 8080 > ~/owui.log 2>&1 &

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
2. Pick the model shown (e.g. `granite3.1-moe`).
3. Start chatting! Try these prompts:

#### Prompt 1 — Technical (computer architecture)

> Explain in detail how a modern x86 CPU executes a single instruction, end to end: instruction fetch, decode, register rename, dispatch, out-of-order execution, the role of the memory hierarchy (L1/L2/L3 cache, TLB, store buffer), retirement, and how branch prediction and speculative execution affect throughput. Aim for at least 600 words and use clear headings.

#### Prompt 2 — Creative (long-form story)

> Write an 800-word short story set in 100 AD about a Roman aqueduct engineer named Lucius who unearths a mysterious mechanical artifact beneath the Forum while inspecting a damaged conduit. Include character dialogue, sensory description of the underground passages, and a clear three-act structure ending with an unsettling discovery.

#### Prompt 3 — Comparative (deep technical comparison)

> Compare TCP and UDP in depth — protocol design, header field layouts, connection setup and teardown, reliability, ordering, flow control, congestion control mechanisms (Reno, CUBIC, BBR), latency and throughput trade-offs, and at least four real-world applications where one is preferred over the other (such as video conferencing, file transfer, gaming, DNS, and live streaming). Aim for at least 700 words and structure it with headings.

Open WebUI shows an **ℹ️ info button** (small `i` icon) in the action bar below each completed answer — click it to see token usage details.

Prefill Tokens/sec = prompt_per_second
Decode Tokens/sec = predicted_per_second

### 1.9 Measure prefill and decode speed directly

To get precise **prefill** and **decode** tok/s numbers, use the llama-server API directly from your SSH session:

```bash
curl -s http://127.0.0.1:8001/completion \
  -H "Content-Type: application/json" \
  -d '{
    "prompt": "Compare TCP and UDP in depth: protocol design, headers, reliability, congestion control, four real-world applications. 700+ words.",
    "n_predict": 300,
    "stream": false
  }' | jq '{
    prefill_tps: .timings.prompt_per_second,
    decode_tps: .timings.predicted_per_second,
    prompt_tokens: .timings.prompt_n,
    gen_tokens: .timings.predicted_n
  }'
```

You should see output like:

```json
{
  "prefill_tps": 72.4,
  "decode_tps": 15.3,
  "prompt_tokens": 38,
  "gen_tokens": 300
}
```

| Metric | What it measures | Bottleneck |
|---|---|---|
| `prefill_tps` | How fast the model digests the prompt before generating | **Compute-bound** — this is where AMX matrix tiles dominate |
| `decode_tps` | How fast the model generates output tokens one by one | **Memory-bandwidth bound** — DDR5 on Xeon 6 helps here |

Both numbers benefit from the Xeon 6 architecture. The `prefill_tps` is the key AMX metric — in production workloads with long prompts or batched requests, prefill speed dominates total latency.

### 1.10 Leave the instance running for now

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
- Deployed an AWS EC2 Xeon 6 instance, built llama.cpp with `GGML_AMX=ON`, and **ran a real GenAI workload accelerated by Intel AMX**.
- Proved Intel AMX is present on GCP Xeon 6 (and absent on ARM).
- Tore it all down.

That's the entire loop a customer goes through when they evaluate Intel-on-cloud. Now you can demo it.

---

## Appendix — If something goes wrong

The issues you are most likely to hit, with the exact one-liner that fixes each. **Raise your hand** if a fix below doesn't unblock you within 2 minutes.

| You see | What it means | What to do |
| --- | --- | --- |
| `winget : The term 'winget' is not recognized` | Old Windows / IT disabled App Installer | Use **Path B** (manual installers) in step 0.2 |
| `cannot be loaded because running scripts is disabled on this system` | PowerShell execution policy | Run `Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned`, then retry |
| `git` / `terraform` / `code` / `gcloud` `not recognized` right after install | PowerShell PATH is cached | **Close PowerShell, open a new one**, retry |
| Module 1 `terraform apply` → `InsufficientInstanceCapacity` for `m8i.4xlarge` | Region/AZ ran out of `m8i` capacity | **Raise your hand** — instructor will switch the region |
| Module 1 `ssh -F ssh_config vm` → "Connection refused" | Instance still booting (sshd not up yet) | Wait ~30s and retry |
| Module 1 SSH → hangs at `connecting...` forever | `ssh_config` uses Intel proxy; you're off Intel network | Use `ssh_config_no_proxy` instead |
| Module 1 `ollama pull` looks frozen | First-time pull — it's downloading, just slow | Be patient; if it errors, re-run the same command (it resumes) |
| Module 1 `cmake --build` fails | Missing build deps or low disk | Re-run `sudo apt-get install -y build-essential cmake git` and retry |
| Module 1 llama-server `--model` is empty | `$GGUF_PATH` was blank (Ollama was stopped when you ran `ollama show`) | Restart Ollama (`sudo systemctl start ollama`), re-run the `GGUF_PATH=...` + `sudo cp` commands, then stop Ollama and restart llama-server |
| Module 1 Open WebUI model dropdown empty | llama-server did not load the model | Check `cat ~/llama-server.log`; kill and re-launch with the correct `--model ~/model.gguf` path |
| Module 1 browser → `ERR_CONNECTION_REFUSED` on `:8080` | Open WebUI hasn't finished starting | Wait 30s; in the SSH session, run `tail ~/owui.log` to confirm it's up |
| Module 2 `terraform apply` → `google: could not find default credentials` | Forgot the second `gcloud` login | Run `gcloud auth application-default login`, then `terraform apply` again |
| Module 2 `terraform apply` → `network 'default' not found` | Project has no default VPC | **Raise your hand** — instructor needs to create it |
| Module 2 SSH → hangs at `connecting...` forever | `ssh_config` uses Intel proxy; you're off Intel network | `ssh -F ssh_config_no_proxy vm` |
| `terraform destroy` says `Error: ... still in use` | A previous `apply` was interrupted | Re-run `terraform destroy -auto-approve` once more; it usually clears |

When in doubt: from the `cloud-workshop` folder, run `.\prereqs\verify-tools.ps1` again — it confirms every tool is present and on PATH.
