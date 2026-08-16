---
name: life-os
description: Operate the user's private Notion Life OS. Use when asked to capture or file something, add a task/note/project/transaction/shopping item/contact/time entry, retrieve what needs attention, plan meals, run a weekly reset, or maintain the Saturday/Sunday routine handoff.
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
- Finite multi-step outcome → Projects with Area and observable definition of done when known.
- Purchase reminder → Shopping.
- Person or organization → Contacts & CRM; never invent personal details.
- Time log → Time Entries with date, duration, and one of Phase0, Frisch, reverie.pics, or Personal.
- Money movement → Transactions only after amount, date, direction, currency, scope, and Account are known. Amount stays positive; Direction controls reporting sign.
- Appointment, booking, travel time, soundcheck, or set time → Google Calendar when Calendar mutation is explicitly requested. Create Tasks only for preparation or follow-up.

Work contexts are Phase0, Frisch, reverie.pics, and DJ & Events. Employer/client/customer-sensitive data stays in approved external systems.

## Meal planning

When the user asks to start meal planning:

1. Check the coming Calendar week for busy, away, guest, and delivery constraints.
2. Read Recipes and recent Meal Plans.
3. Ask at most four missing decision questions: number of meals, portions, exclusions/cravings, and what is already in stock.
4. Propose realistic meals plus low-effort fallbacks.
5. After approval, create one dated Meal Plan and relate Recipes.
6. Propose missing groceries, merge obvious duplicates, and create only approved Shopping items.
7. Return links to the Meal Plan and Groceries.

If Saturday was missed, make a three-day plan from today. Do not backfill.

## Weekly reset

When the user asks to start the weekly reset:

1. Create a dated Weekly Review from the weekly checklist and return its link.
2. Guide one section at a time: Calendar → Inbox → overdue/unscheduled Tasks → active Projects → food → genuine domain exceptions → Monday's first Task.
3. On the first Sunday of a month, include finance, administration, account snapshot, bills, subscriptions, payouts, and home-maintenance exceptions.
4. On the first Sunday of January, April, July, or October, include goals and capacity; reduce active commitments before adding any.
5. Before completion, ensure exactly one open `Plan meals and order groceries` Task exists for the following Saturday at 10:00 Europe/Berlin and exactly one open `Weekly reset` Task exists for the following Sunday at 17:00 Europe/Berlin. Search scheduled instances first. Duplicate the corresponding current Task only when missing, then reset its title, Status, Schedule, and completion data while preserving its content, Area, Assignee, Type, Recurrence, Sharing Scope, and Source Note.
6. Return links to the Review and both next routine Tasks.

If resets were missed, do one recovery pass from today. Never create backdated Reviews to fill history.

## Boundaries

- Google Calendar owns events; Notion owns Tasks. Avoid duplicate recurrence.
- Keep finance, health, work, and private Notes private by default.
- Never request bank credentials or scrape bank sessions. Use user-approved CSV/manual finance ingestion.
- Never inspect an Obsidian source until the user selects the exact source and scope.
- Sharing, invitations, payments, credentials, irreversible deletion, and external messages require explicit confirmation.
- Archive synthetic and obsolete records rather than leaving misleading live data.
