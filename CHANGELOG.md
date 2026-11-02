# Changelog

## Unreleased

- Add optional event value queries and compare event/repetition/start-when-available task drift.

## 0.1.0 (unreleased)

- `New-NSPScheduledTaskDefinition`, `Register-NSPScheduledTask`, `Test-NSPScheduledTask`: one
  definition registers a task and checks an installed one for drift (action, account, run level,
  settings, triggers).
- `New-NSPEventTaskTrigger`: event-log triggers (log + IDs + provider, or a full query).
- Extracted from two client file-transfer jobs, which registered gMSA tasks on a Sysmon
  file-create event and on a nightly schedule.
