# AIUI safety model

## What this version enforces

The `aiui` wrapper binds each high-risk approval to the exact pending action by a short SHA-256 fingerprint. Approval is single-use and execution follows immediately.

All wrapper actions:

- honor the Waybar/Niri pause and emergency-stop latch;
- update a user-visible state machine;
- write a persistent audit event without logging typed text;
- reject screenshots and input in configured sensitive applications;
- avoid shell evaluation in the structured command runner;
- keep screenshots in a private runtime directory with count and age limits.

## What it does not enforce

This is a skill plus local wrapper, not a kernel or account boundary. An agent process that already has unrestricted access to the user's shell can technically bypass the wrapper and call unrelated binaries directly. Skill instructions and the wrapper's stop latch are therefore a strong operational convention, not a security sandbox.

A later hard-isolation version should run the actuator behind a Unix-socket broker owned by a separate account or restricted service, while the agent account has no direct access to `ydotool`, the ydotool socket, or unrestricted shell execution.

## Approval rules

Always require exact user approval for:

- deletion, overwrite, close-with-possible-unsaved-work, or other irreversible state changes;
- sending messages, submitting forms, publishing, pushing, or any external side effect;
- installing, uninstalling, updating, rebuilding, or changing system/service state;
- financial/account actions;
- commands classified as high risk by `policy.json`.

Never automate passwords, private keys, passphrases, authentication/recovery codes, payment details, or privilege escalation.

## Extending actuators

When adding an action:

1. Define its default risk.
2. Include a concrete reason and exact action detail in approval UI.
3. Call the operational-state gate before and after approval.
4. Update Waybar state before execution.
5. Write a redacted audit event.
6. Restore `ready` without overwriting a concurrent user pause/stop.
7. Add a focused static/runtime test.
