# Workshop Pitch

## Title

**From Zero to Xeon: Deploy & Validate Intel Instances on AWS and GCP in 2 Hours**

## Abstract

In this session you will deploy real Intel-powered services in two major clouds — AWS and GCP — and validate it yourself that Intel Xeon silicon is doing the work. On AWS you'll deploy two EC2 instances side by side — an older `m5.4xlarge` (Skylake/Cascade Lake Xeon) and a newer `m8i.4xlarge` (Xeon 6 with Intel AMX) — install [Ollama](https://github.com/ollama/ollama) with the `qwen3:30b-a3b-q8_0` 30 B-parameter Mixture-of-Experts model and the [Open WebUI](https://docs.openwebui.com/) interface on each, and watch the same prompt return measurably faster on the newer silicon. Then you'll spin up a Google Cloud VM, discover it lacks Intel AMX because it's running on ARM, swap it to a Xeon 6 instance, and watch AMX appear. You will also learn how to use Infrastructure-as-Code with Terraform. No prior cloud experience required. You leave able to demo Intel-on-cloud to any customer.

## Why this wins a slot (talking points for the selection committee)

- **Differentiated**: most workshops teach *one* cloud or *one* tool. This session has attendees touch two hyperscalers **and** quantify a generational Intel performance delta in their own browser.
- **Sales-enabling**: every Technical Seller leaves with a script they can re-run in front of a customer to *prove* a Xeon-6 perf uplift, or to *prove* AMX is present on Intel and missing on ARM.
- **Zero prerequisite**: built for sellers who have never used VSCode, Git, a CLI, or Terraform. We bring them up the curve in Module 1 and they fly through Module 2.
- **Repeatable**: 100 % infrastructure-as-code. Cleanup is one command. No "lab leftovers" billing surprises.
- **Right-sized**: 2 hands-on modules + 15 min setup + 10 min teardown + Q&A = 2 hours, paced for novices.

## Logistics one-liner

Bring a Windows laptop with PowerShell. We provide the sandbox cloud accounts, the repo, and a short prereq script. You provide the curiosity.

## Your call to action

Before you leave the room, write down:
1. **One customer** in your pipeline this quarter.
2. **One workload** of theirs that maps to a training today — local LLM inference / GenAI on Xeon 6 (Module 1), or AI/analytics on AMX (Module 2).
3. **One next step on the calendar** — a customer meeting on scaling to a joint PoC running similar workloads on Intel in the cloud.
