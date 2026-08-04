# AWS — Agentic AI on Xeon 6 with Hermes Agent (90 minutes)

Welcome! Follow these steps **in order**. If you get stuck for more than 2 minutes, **raise your hand** — do not silently fall behind.

> Everything in this workshop runs from **Windows PowerShell**. When you see a gray box with commands, copy/paste it into PowerShell.

## What you will build

Deploy an AWS EC2 **Xeon 6** instance with Intel AMX, build [llama.cpp](https://github.com/ggml-org/llama.cpp) from source with AMX acceleration, and run [Hermes Agent](https://hermes-agent.nousresearch.com/) — an autonomous AI agent by Nous Research — on a local LLM. You'll watch the agent use tools (terminal, file I/O, code execution) autonomously to complete real tasks on your server.

In order, you will:

1. Deploy an AWS EC2 `m8i.4xlarge` (Xeon 6 with **AMX**, 16 vCPU, 64 GB DDR5).
2. Build llama.cpp from source with **`GGML_AMX=ON`** for hardware-accelerated inference.
3. Install Hermes Agent and connect it to the local AMX-accelerated model.
4. Watch the agent autonomously use tools to complete real tasks, then measure AMX inference performance.

---

## 1 Sign in to AWS

You will receive a **handout** with sandbox credentials. Run this and follow the prompts:

```powershell
aws configure
# Paste the provided Access Key, Secret
# Region: us-east-1
# Output format: json
```

## 2 Pick your unique name prefix

Pick a short **lowercase** prefix that nobody else will pick — your **first name** works well (e.g., `bob`). Keep it 3–10 letters, no spaces or capitals. **Write it down** — you'll type it in the next step.

---

## 3 Move into the AWS folder

```powershell
cd terraform-aws
```

## 4 Create your `terraform.tfvars`

```powershell
Copy-Item terraform.tfvars.example terraform.tfvars
code terraform.tfvars
```

1. In VSCode, change `name_prefix = "changeme"` to your first name (e.g., `bob`).
2. Remove the comment `#` .
3. Save the file.

## 5 Deploy the Intel Xeon 6 instance with Terraform

On the VSCode Terminal run Terraform

```powershell
terraform init
terraform apply 
```

1. Monitor the output. Terraform is telling AWS to create a new EC2 instance, security group, and key pair. The `terraform apply` step shows you the **plan** of what will be created.
2. Enter `yes` to confirm. Terraform will then create the resources.
3. `apply` takes ~2 minutes. When it finishes Terraform prints outputs including `public_ip` and `ssh_command`.

## 6 SSH into the instance and Validate AMX is present

```powershell
ssh -F ssh_config vm
```

> If you're off Intel's network, use `ssh -F ssh_config_no_proxy vm` instead.

You are now logged into an Ubuntu box running on Xeon 6. The shell prompt looks like `ubuntu@ip-...`.

Validate AMX is present on new VM
```bash
lscpu
# Validate Flags show "amx"
```

## 7 Install Ollama and pull the model

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
# 3. Pull the model (~5 GB download)
ollama pull granite4.1:8b
```

> **Why granite4.1:8b?** Hermes Agent requires a model with strong tool-calling capability. IBM Granite 4.1 8B has enterprise-grade function-calling training, native 128K context, no "thinking" overhead (responds directly without hidden reasoning tokens), and is explicitly listed as Hermes-compatible on Ollama. Apache 2.0 license.

## 8 Build llama.cpp with AMX

Stock Ollama ships a pre-built `llama.cpp` binary that uses AVX-512 but **does not enable the `GGML_AMX` backend**. Building from source with `-DGGML_AMX=ON` lights up the AMX matrix tiles for GEMM operations, giving a significant speedup on compute-bound prefill.

Intel Blog with llama.cpp + AMX performance: [https://community.intel.com/t5/Blogs/Tech-Innovation/Artificial-Intelligence-AI/Optimizing-SLMs-on-Intel-Xeon-Processors-A-llama-cpp-Performance/post/1734305](https://community.intel.com/t5/Blogs/Tech-Innovation/Artificial-Intelligence-AI/Optimizing-SLMs-on-Intel-Xeon-Processors-A-llama-cpp-Performance/post/1734305)

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
GGUF_PATH=$(ollama show granite4.1:8b --modelfile | grep '^FROM ' | awk '{print $2}')
echo "Ollama blob: $GGUF_PATH"
sudo cp "$GGUF_PATH" ~/model.gguf
sudo chown ubuntu:ubuntu ~/model.gguf
echo "Copied: $(ls -lh ~/model.gguf | awk '{print $5}')"
```

```bash
# 4. Stop Ollama, start llama-server with AMX + tool calling support
sudo systemctl stop ollama

nohup ~/llama.cpp/build/bin/llama-server \
  --model ~/model.gguf \
  --alias granite4.1-8b \
  --host 127.0.0.1 --port 8001 \
  --threads 16 --ctx-size 131072 \
  --jinja --flash-attn on \
  > ~/llama-server.log 2>&1 &

until curl -fs http://127.0.0.1:8001/health > /dev/null 2>&1; do echo "waiting for llama-server..."; sleep 2; done
echo "llama-server is up with AMX + tool calling"
```

> **Key flags:**
> - `--jinja` — **Required** for tool/function calling. Without this, the model cannot execute tools.
> - `--flash-attn on` — Flash attention for memory-efficient long-context inference.
> - `--ctx-size 131072` — 128K context window (Granite 4.1's native training length).
> - `--threads 16` — Uses all 16 vCPUs for inference.

<!-- Verify AMX is active:

```bash
grep 'AMX_INT8\|AMX_BF16\|REPACK' ~/llama-server.log | head -5
```

You should see `AMX_INT8 = 1`. Verify tool calling is enabled: -->

```bash
curl -s http://127.0.0.1:8001/props | python3 -c "import sys,json; d=json.load(sys.stdin); print('Tool calling:', 'ENABLED' if d.get('chat_template') else 'DISABLED')"
```

## 9 Install Hermes Agent

[Hermes Agent](https://hermes-agent.nousresearch.com/) is an autonomous AI agent built by [Nous Research](https://nousresearch.com/). Unlike a simple chatbot, it has a **learning loop** — it creates skills from experience, uses 70+ built-in tools (terminal, file I/O, web search, code execution), and improves over time.

```bash
# Install Hermes Agent (handles Python, Node.js, ripgrep, ffmpeg automatically)
curl -fsSL https://raw.githubusercontent.com/NousResearch/hermes-agent/main/scripts/install.sh | bash
```

> **Setup wizard:** The installer will launch a setup wizard at the end. When it asks about "Inference Provider" and tries to log in to Nous Portal, press **Ctrl+C** to skip it — we'll configure the model manually in the next step.

```bash
# Reload shell so the `hermes` command is available
source ~/.bashrc
```

## 10 Configure Hermes Agent to use the local model

Point Hermes Agent at your local llama-server. This tells it to use your AMX-accelerated model instead of a cloud API:

```bash
# Configure the LLM provider as a custom local endpoint
hermes config set model.provider custom
hermes config set model.default "granite4.1-8b"
hermes config set model.base_url "http://localhost:8001/v1"
hermes config set model.context_length 131072
```

<!-- Verify the configuration:

```bash
hermes doctor
```

You should see your model and provider listed without errors. -->

## 11 Run your first agentic conversation

Start Hermes Agent in interactive mode:

```bash
hermes chat
```

You'll see a welcome banner showing your model (`granite4.1-8b`), available tools, and a prompt. **This is not a chatbot** — it's an agent that can autonomously execute commands, read/write files, and chain multi-step tasks.

Type this first prompt to verify tool use works:

```
What directory am I in? List the files here and tell me about this system.
```

> **Timing:** Each inference turn takes ~10-20 seconds on CPU with AMX acceleration. Multi-step tasks with tool calls will take 1-4 minutes total. Granite 4.1 responds directly without hidden "thinking" tokens, making it faster than models with reasoning overhead.

The agent should:
1. Run `pwd` to check the current directory
2. Run `ls` to list files
3. Possibly run `uname -a` or `lscpu` to gather system info
4. Synthesize the results into a coherent answer

> **What's different from a chatbot?** A chatbot generates text. Hermes Agent **takes action** — it decides which tools to call, executes them, reads the output, and iterates. You'll see it "thinking" and running commands in real-time.

## 12 Agentic demo — real-world tasks

Now try these prompts that demonstrate autonomous multi-step capabilities. Enter them one at a time in the Hermes session (or use `hermes chat -q "your prompt" --yolo` for non-interactive single queries):

### Prompt 1 — Hardware discovery (terminal tools)

```
Check this machine's CPU — is Intel AMX available? Show me the specific AMX flags from /proc/cpuinfo, then explain what each one means and why it matters for AI inference.
```

The agent will autonomously `grep` through `/proc/cpuinfo`, find the AMX flags (`amx_tile`, `amx_int8`, `amx_bf16`), and explain their significance.

### Prompt 2 — Multi-step coding task (file + terminal tools)

```
Create a directory called ~/demo. Write a Python script there that benchmarks matrix multiplication using numpy — compare a 1024x1024 and a 4096x4096 matrix multiply, timing each one 5 times and reporting the average. Then run the script and show me the results.
```

Watch the agent:
1. Create the directory
2. Write a complete Python script
3. Install numpy if needed
4. Execute the script
5. Present the benchmark results

### Prompt 3 — System analysis (multi-tool orchestration)

```
Analyze this machine's full hardware profile: CPU model, core count, AMX capabilities, total RAM, disk space, and network interfaces. Then check if the llama-server process is running and healthy. Present everything as a clean summary.
```

The agent will orchestrate multiple commands (`lscpu`, `free -h`, `df -h`, `ip addr`, `curl` to the health endpoint) and synthesize everything into a report.

## 13 Explore Hermes Agent features

While still in the Hermes session, try these slash commands:

| Command | What it does |
|---------|-------------|
| `/tools` | List all available tools the agent can use |
| `/help` | Show all slash commands |
| `/model` | Show current model info |
| `Ctrl+C` | Interrupt the agent if it's taking too long |

To exit Hermes Agent, type `/quit` or press `Ctrl+D`.

## 14 Measure inference performance with AMX

Back in the regular shell (after exiting Hermes), measure raw AMX-accelerated performance:

```bash
curl -s http://127.0.0.1:8001/completion \
  -H "Content-Type: application/json" \
  -d '{
    "prompt": "Explain how Intel AMX (Advanced Matrix Extensions) accelerates AI inference workloads on Xeon processors. Cover the architecture of the TMUL unit, the tile registers, and how INT8/BF16 matrix operations map to real-world neural network layers.",
    "n_predict": 300,
    "stream": false
  }' | python3 -c "
import sys, json
d = json.load(sys.stdin)
t = d['timings']
print(f\"Prefill:  {t['prompt_per_second']:.1f} tok/s  ({t['prompt_n']} tokens)\")
print(f\"Decode:   {t['predicted_per_second']:.1f} tok/s  ({t['predicted_n']} tokens)\")
print(f\"\\nPrefill is compute-bound → AMX matrix tiles dominate here.\")
print(f\"Decode is memory-bound → DDR5 bandwidth on Xeon 6 helps here.\")
"
```

## 15 Teardown — DO NOT SKIP

When you're done exploring, first leave the SSH session (type `exit`) to return to Windows PowerShell. Then tear everything down so the sandbox stops billing:

```powershell
cd $HOME\solutions-execution\workshop\cloud-workshop\terraform-aws
terraform destroy
```

1. Review the plan. Terraform shows you everything it will **destroy** (the EC2 instance, security group, and key pair).
2. Enter `yes` to confirm. Terraform tears down the resources and ends with `Destroy complete!`.

**Show your screen to a workshop assistant before you leave.**

---

## You did it

In this workshop you:

- Used VSCode, Git, the AWS CLI, and Terraform for the first time.
- Deployed an AWS EC2 Xeon 6 instance and built llama.cpp with `GGML_AMX=ON` for hardware-accelerated inference.
- Installed **Hermes Agent** — an autonomous AI agent by Nous Research — and connected it to a local LLM running on Intel AMX.
- Watched the agent **autonomously use tools** (terminal commands, file I/O, code execution) to complete real tasks — going far beyond simple chatbot Q&A.
- Measured prefill and decode performance powered by Intel AMX.

That's the full stack: Intel silicon → open-source inference engine → autonomous AI agent. All running locally on your server with zero cloud API dependencies.

---

## Appendix — If something goes wrong

| You see | What it means | What to do |
| --- | --- | --- |
| `winget : The term 'winget' is not recognized` | Old Windows / IT disabled App Installer | Use **Path B** (manual installers) in step 1.2 |
| `cannot be loaded because running scripts is disabled on this system` | PowerShell execution policy | Run `Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned`, then retry |
| `git` / `terraform` / `code` / `gcloud` `not recognized` right after install | PowerShell PATH is cached | **Close PowerShell, open a new one**, retry |
| `terraform apply` → `InsufficientInstanceCapacity` | Region/AZ ran out of `m8i` capacity | **Raise your hand** — instructor will switch the region |
| `ssh -F ssh_config vm` → "Connection refused" | Instance still booting (sshd not up yet) | Wait ~30s and retry |
| SSH → hangs at `connecting...` forever | `ssh_config` uses Intel proxy; you're off Intel network | Use `ssh -F ssh_config_no_proxy vm` instead |
| `ollama pull` looks frozen | First-time pull — it's downloading, just slow | Be patient; if it errors, re-run the same command (it resumes) |
| `cmake --build` fails | Missing build deps or low disk | Re-run `sudo apt-get install -y build-essential cmake git` and retry |
| llama-server `--model` is empty | `$GGUF_PATH` was blank (Ollama was stopped when you ran `ollama show`) | Restart Ollama (`sudo systemctl start ollama`), re-run the `GGUF_PATH=...` + `sudo cp` commands, then stop Ollama and restart llama-server |
| `hermes` → slow responses with visible "thinking" | Model has reasoning overhead | This shouldn't happen with Granite 4.1 — verify `hermes config set model.default` shows `granite4.1-8b` |
| `hermes` → "command not found" | Shell not reloaded after install | Run `source ~/.bashrc` and retry |
| `hermes` → empty or broken replies | Model/endpoint config wrong | Run `hermes doctor`, verify llama-server is running (`curl http://127.0.0.1:8001/health`) |
| `hermes` → "Context limit" error at startup | llama-server context too small | Ensure you started with `--ctx-size 131072` |
| `hermes` → tool calls appear as text (raw JSON) | `--jinja` flag missing on llama-server | Kill llama-server, restart with `--jinja` flag |
| `terraform destroy` says `Error: ... still in use` | A previous `apply` was interrupted | Re-run `terraform destroy` once more (type `yes`); it usually clears |

When in doubt: from the `cloud-workshop` folder, run `.\prereqs\verify-tools.ps1` again — it confirms every tool is present and on PATH.

---

## Appendix — What is Hermes Agent?

[Hermes Agent](https://hermes-agent.nousresearch.com/) is an open-source (MIT license) autonomous AI agent built by [Nous Research](https://nousresearch.com/). Key features:

- **70+ built-in tools** — terminal commands, file operations, web search, browser automation, code execution, image generation, and more.
- **Self-improving** — creates skills from experience and reuses them. Persistent memory across sessions.
- **Runs anywhere** — local machine, Docker, SSH, serverless (Daytona, Modal). Not tethered to an IDE.
- **Any LLM backend** — works with Ollama, llama.cpp, vLLM, or any OpenAI-compatible API.
- **Multi-platform** — CLI, Telegram, Discord, Slack, WhatsApp, Email, and 20+ messaging platforms.

Learn more: [Documentation](https://hermes-agent.nousresearch.com/docs/) | [GitHub](https://github.com/NousResearch/hermes-agent) | [Discord](https://discord.gg/NousResearch)
