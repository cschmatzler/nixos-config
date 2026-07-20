---
name: home-assistant
description: Use Home Assistant MCP tools to inspect and control this home. Use when asked about devices, entities, rooms, automations, scenes, energy, climate, media, or current home state.
---

# Home Assistant

Use the `homeassistant` MCP server instead of direct HTTP requests or shell commands.

## Workflow

1. Read live context before answering questions about current state or acting on a device.
2. Resolve ambiguous names by room, area, and entity before changing anything.
3. Make the smallest requested change.
4. Read the resulting state when practical and report whether the action succeeded.

## Confirmation

Ask for explicit confirmation immediately before:

- unlocking doors, opening garage doors, or disarming security systems
- changing locks, alarms, cameras, access control, water, gas, or safety devices
- disabling automations or changing many devices at once
- setting climate controls outside ordinary occupied-home ranges
- actions that could wake people, reveal private information, or cause physical damage

Routine, reversible actions on a clearly identified light, media player, scene, or ordinary climate setting do not require extra confirmation.

## Safety

- Never expose authentication tokens or credentials.
- Never infer that a safety-critical action succeeded; verify its reported state.
- Do not change Home Assistant configuration, entity exposure, users, or permissions unless explicitly requested.
- If an entity is unavailable or the target is ambiguous, stop and explain rather than guessing.
