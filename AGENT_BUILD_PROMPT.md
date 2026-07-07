# Agent Build Prompt

Copy this prompt into your AI coding agent.

```text
You are building Hermes Autopilot Kit from scratch.

Goal:
Create a self-improving Hermes ops agent for a non-technical user. The user should provide only credentials. You must install, configure, test, and document everything else.

Read docs/hermes-autopilot-kit/README.md first and follow it as the system-of-record.

Non-negotiables:
- Do not ask the user to hand-edit config files.
- Do not store secrets in Git.
- Prefer markdown files as durable memory.
- Prefer deterministic no-agent jobs for health checks and backups.
- Wake the LLM only when judgment is needed.
- Every recurring job must write a receipt.
- Every risky action must require human approval.
- The system must survive restart.

Required build steps:
1. Inspect host OS and runtime.
2. Install or verify Docker.
3. Create persistent data directories.
4. Deploy Hermes.
5. Configure model provider.
6. Configure Discord or Slack gateway.
7. Create BrainCache markdown repo.
8. Install and configure GBrain indexing unless the user disables it.
9. Install starter skills.
10. Create starter cron jobs.
11. Add gateway watchdog.
12. Add backup job.
13. Add self-improvement scorecard job.
14. Run acceptance checks.
15. Write final handoff with URLs, commands, and what was verified.

If something fails:
- Attribute the failure to one layer: runtime, credentials, gateway, brain, skill, cron, backup, or model.
- Fix the layer.
- Rerun the check.
- Write the failure and fix into a receipt.

Definition of done:
- Hermes gateway is online.
- Chat platform receives a test message.
- Brain page write/read works.
- GBrain is initialized and synced, or markdown-only fallback is clearly reported.
- At least one receipt exists.
- Backup repo has a commit.
- Self-improvement scorecard exists.
- Restart test passes.
```
