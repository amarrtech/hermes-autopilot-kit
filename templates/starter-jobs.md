# Starter Jobs

Use this as the initial job registry.

## gateway-health

- schedule: every 15 minutes
- agent: false
- action: check Hermes gateway and chat connection
- alert: only when status changes from ok to failed
- receipt: `brain/receipts/gateway-health/`

## brain-sync

- schedule: every 5 minutes
- agent: false
- action: sync markdown brain into GBrain
- alert: only after 3 consecutive failures
- receipt: `brain/receipts/brain-sync/`

## weekly-backup

- schedule: weekly
- agent: false
- action: push brain and Hermes config backup to GitHub
- alert: on failure
- receipt: `brain/receipts/weekly-backup/`

## weekly-self-improvement

- schedule: weekly
- agent: true
- action: inspect receipts, logs, failed jobs, noisy alerts, and stale skills
- output: `brain/scorecards/YYYY-WNN.md`
- alert: send concise summary

## weekly-contradiction-scan

- schedule: weekly
- agent: optional
- action: compare stable concept pages against recent daily notes
- output: `brain/synthesis/weekly-contradiction-check-YYYY-MM-DD.md`

## takeaway

- schedule: manual
- agent: true
- action: read a URL or transcript, extract lessons, connect to brain
- output: ask before saving

