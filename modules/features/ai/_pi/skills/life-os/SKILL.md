---
name: life-os
description: Operate the user's private Notion Life OS. Use when asked to capture or file something, add a task/note/project/contact, retrieve what needs attention, or run the weekly reset.
---

# Life OS

Operate the private Notion workspace through MCP while keeping machine-facing instructions out of user-visible Notion pages. Address the user directly and describe outcomes rather than database mechanics.

Read [references/notion-ids.md](references/notion-ids.md) before the first Notion mutation in a session. The optional local registry at `/home/cschmatzler/research/notion-life-os-implementation.md` contains deeper implementation history but is not required for ordinary operation.

## Interaction

1. Interpret ordinary language; the user need not memorize commands.
2. Ask only for facts required to make the requested record truthful. Ambiguous thoughts require no clarification: place them in Inbox.
3. Make the smallest requested mutation.
4. Return a short summary and direct Notion link for every created or changed record.
5. Keep implementation terms such as routing contract, mutation, schema, deduplication, and handoff out of visible Notion content.

Pi in this workflow means the Pi assistant using Notion MCP. It does not mean Notion AI and requires no Notion AI purchase.

## Routing

- Ambiguous thought, brain dump, or dictation → Inbox.
- Action → Tasks. Set only properties stated or safely established from context.
- Context, decision, meeting note, reference, or document → Notes. Commitments inside it become related Tasks.
- Finite multi-step outcome → Projects with an observable definition of done when known.
- Person or organization → Contacts & CRM; never invent personal details.
- Appointment, booking, travel time, soundcheck, or set time → Google Calendar when Calendar mutation is explicitly requested. Create Tasks only for preparation or follow-up.

Work contexts are Phase0, Frisch, Reverie, and DJ & Events. Employer/client/customer-sensitive data stays in approved external systems.

## Weekly reset

When the user asks to start the weekly reset:

1. Create a dated Weekly Review from the weekly checklist and return its link.
2. Guide one section at a time: Calendar → Inbox → overdue/unscheduled Tasks → active Projects → genuine domain exceptions → Monday's first Task.
3. Before completion, ensure exactly one open `Weekly reset` Task exists for the following Sunday at 17:00 Europe/Berlin. Search scheduled instances first. Duplicate the current Task only when missing, then reset its title, Status, Schedule, and completion data while preserving its content, Assignee, Type, Recurrence, Sharing Scope, and Source Note.
4. Return links to the Review and the next reset Task.

If resets were missed, do one recovery pass from today. Never create backdated Reviews to fill history.

## Boundaries

- Google Calendar owns events; Notion owns Tasks. Avoid duplicate recurrence.
- Keep health, work, and private Notes private by default.
- Never inspect an Obsidian source until the user selects the exact source and scope.
- Sharing, invitations, payments, credentials, irreversible deletion, and external messages require explicit confirmation.
- Archive synthetic and obsolete records rather than leaving misleading live data.
