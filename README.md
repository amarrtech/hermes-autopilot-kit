# Hermes Autopilot Kit

Free, open-source playbook for building a self-improving Hermes agent from scratch.

Use this when you want an AI agent to set up Hermes for a non-technical user with almost no manual steps.

## Promise

Hermes Autopilot is a private ops agent that:

- watches important workflows
- sends useful Discord or Slack reports
- saves durable memory to a markdown brain
- writes receipts for every run
- notices repeated failures
- improves its own skills and playbooks over time

The user should only provide credentials. The AI agent should do the rest.

## User Inputs

Minimum:

- VPS or local machine access
- Discord bot token or Slack app token
- model provider key or login method
- GitHub repo for backups

Optional:

- domain name
- Cloudflare tunnel
- X API / xurl credentials
- Google Workspace credentials
- Stripe key for spend/watch workflows

Never ask the user to edit Docker files, cron files, or YAML by hand.

## Target Architecture

```text
User
  |
  v
Discord / Slack
  |
  v
Hermes Agent
  |-- skills/
  |-- cron jobs
  |-- logs
  |-- receipts
  |
  v
GBrain / BrainCache
  |-- markdown notes
  |-- daily memos
  |-- scorecards
  |-- contradiction reports
  |
  v
GitHub Backup Repo
```

## What The AI Agent Must Build

### 1. Runtime

- Install Docker or use existing Docker.
- Create persistent data directory.
- Run Hermes in a container.
- Start Hermes gateway for Discord or Slack.
- Add a watchdog so gateway restarts if it dies.
- Run `hermes doctor` and fix basic issues.

### 2. Brain

- Create a separate markdown repo, for example `BrainCache`.
- Install GBrain or compatible markdown-first brain.
- Store all durable knowledge as markdown first.
- Treat the database/vector index as rebuildable.
- Sync markdown into GBrain on a schedule.

### 3. Skills

Install these starter skills:

- `takeaway` — extract durable lessons from links and videos
- `topic-synthesis` — summarize everything the brain knows about a topic
- `self-improvement-engine` — inspect failures and improve playbooks
- `brain-ops` — search, write, and repair brain notes
- `backup-ops` — verify GitHub backups
- `gateway-health` — check Discord/Slack gateway health
- `competitor-watch` — monitor products or companies
- `content-drafts` — draft X/LinkedIn posts, never auto-post without approval

### 4. Default Jobs

Create these recurring jobs:

| Job | Frequency | Agent? | Output |
|---|---:|---:|---|
| Gateway health check | every 15 min | no | alert only if down |
| Brain sync | every 5 min | no | sync log |
| Daily signal memo | daily | yes | brain page + chat summary |
| Weekly self-improvement | weekly | yes | scorecard |
| Weekly contradiction scan | weekly | no or yes | contradiction report |
| Backup check | weekly | no | GitHub backup receipt |
| Competitor watch | weekly | yes | product notes |
| Content draft review | manual | yes | draft files only |

Use `no_agent` for deterministic checks. Wake the LLM only when a result needs judgment.

### 5. Receipts

Every job must write a receipt:

```markdown
---
type: receipt
job_id: <stable-id>
status: ok | failed | partial
created_utc: <iso timestamp>
---

# <Job Name> Receipt

- Trigger:
- Inputs:
- Files changed:
- Checks passed:
- Checks failed:
- User attention needed:
- Next run:
```

Receipts go in:

```text
brain/receipts/YYYY-MM-DD/
```

### 6. Self-Improvement Loop

The loop runs weekly:

1. Read failed receipts and logs.
2. Count repeated mistakes.
3. Detect noisy jobs and useless alerts.
4. Find stale skills or missing verification.
5. Propose small fixes.
6. Apply safe fixes automatically.
7. Ask before risky fixes.
8. Write a scorecard.

Scorecard fields:

```yaml
repeat_mistakes: 0
failed_jobs: 0
noisy_alerts: 0
skills_changed: 0
brain_pages_added: 0
contradiction_candidates: 0
backup_status: ok
```

### 7. Safety Rules

- Draft before posting.
- Read-only by default.
- Mutating tools require explicit approval.
- Store secrets outside Git.
- Redact logs before backup.
- Every recurring job must have an owner, purpose, tool scope, and rollback path.

## One-Click Product Shape

For a real hosted version, expose this flow:

1. User clicks **Deploy Autopilot**.
2. User connects Discord or Slack.
3. User connects GitHub backup repo.
4. User chooses model provider.
5. System provisions Hermes, GBrain, skills, and jobs.
6. User gets a message: `Autopilot is live. First health check passed.`

The implementation can begin as a single installer:

```bash
curl -fsSL https://example.com/hermes-autopilot/install.sh | bash
```

The installer should ask only for credentials and confirmations.

## Acceptance Checks

The build is not done until these pass:

```bash
hermes --version
hermes doctor
hermes gateway status
gbrain doctor
git -C ~/brain status
curl -f http://localhost:8765/health
```

Also verify:

- Discord or Slack receives a test message.
- A test receipt is written.
- A brain page can be created and searched.
- Backup repo receives a commit.
- A failed test job creates an alert.
- Self-improvement scorecard is generated.

## Minimal First Launch

Ship only this first:

- Discord gateway
- BrainCache markdown repo
- GBrain sync
- gateway health check
- weekly backup check
- weekly self-improvement scorecard
- `takeaway` skill
- `topic-synthesis` skill

Everything else can be a later module.

## License

MIT. Use, modify, sell hosted services, and share freely.

