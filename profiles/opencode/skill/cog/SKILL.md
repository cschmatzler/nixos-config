---
name: cog
description: Persistent knowledge graph memory via Cog MCP. Use when recording insights, querying prior knowledge, or managing memory consolidation.
metadata:
  author: trycog
  version: "1.0.0"
---

# Cog Memory System

Persistent knowledge graph for teams. Concepts (engrams) linked via relationships (synapses). Spreading activation surfaces connected knowledge.

## Core Workflow

```
1. UNDERSTAND task (read files, parse request)
2. QUERY Cog with specific keywords  <- MANDATORY, no exceptions
3. WAIT for results
4. EXPLORE/IMPLEMENT guided by Cog knowledge
5. RECORD insights as short-term memories during work
6. CONSOLIDATE memories after work (reinforce valid, flush invalid)
```

**Hierarchy of truth:** Current code > User statements > Cog knowledge

---

## Visual Indicators (MANDATORY)

Print before EVERY Cog tool call:

| Tool | Print |
|------|-------|
| `cog_recall` | `Querying Cog...` |
| `cog_learn` | `Recording to Cog...` |
| `cog_associate` | `Linking concepts...` |
| `cog_update` | `Updating engram...` |
| `cog_trace` | `Tracing connections...` |
| `cog_connections` | `Exploring connections...` |
| `cog_unlink` | `Removing link...` |
| `cog_list_short_term` | `Listing short-term memories...` |
| `cog_reinforce` | `Reinforcing memory...` |
| `cog_flush` | `Flushing invalid memory...` |
| `cog_verify` | `Verifying synapse...` |
| `cog_stale` | `Listing stale synapses...` |

---

## Tools Reference

| Tool | Purpose |
|------|---------|
| `cog_recall` | Search with spreading activation |
| `cog_learn` | Create memory with **chains** (sequential) or associations (hub) |
| `cog_get` | Retrieve engram by ID |
| `cog_associate` | Link two existing concepts |
| `cog_trace` | Find paths between concepts |
| `cog_update` | Modify engram term/definition |
| `cog_unlink` | Remove synapse |
| `cog_connections` | List engram connections |
| `cog_bootstrap` | Exploration prompt for empty brains |
| `cog_list_short_term` | List pending consolidations |
| `cog_reinforce` | Convert short-term to long-term |
| `cog_flush` | Delete invalid short-term memory |
| `cog_verify` | Confirm synapse is still accurate |
| `cog_stale` | List synapses needing verification |

---

## Querying Rules

### Before exploring code, ALWAYS query Cog first

Even for "trivial" tasks. The 2-second query may reveal gotchas, prior solutions, or context that changes your approach.

### Query Reformulation (Critical for Recall)

Before calling `cog_recall`, **transform your query from question-style to definition-style**. You are an LLM -- use that capability to bridge the vocabulary gap between how users ask questions and how knowledge is stored.

#### Think like a definition, not a question

| User Intent | Don't Query | Do Query |
|-------------|-------------|----------|
| "How do I handle stale data?" | `"handle stale data"` | `"cache invalidation event-driven TTL expiration data freshness"` |
| "Why does auth break after a while?" | `"auth breaks"` | `"token expiration refresh timing session timeout JWT lifecycle"` |
| "Where should validation go?" | `"where validation"` | `"input validation system boundaries sanitization defense in depth"` |

#### The reformulation process

1. **Identify the concept** -- What is the user actually asking about?
2. **Generate canonical terms** -- What would an engram about this be titled?
3. **Add related terminology** -- What words would the DEFINITION use?
4. **Include synonyms** -- What other terms describe the same thing?

#### Example transformation

```
User asks: "Why is the payment service sometimes charging twice?"

Your thinking:
- Concept: duplicate charges, idempotency
- Canonical terms: "idempotency", "duplicate prevention", "payment race condition"
- Definition words: "idempotent", "transaction", "mutex", "lock", "retry"
- Synonyms: "double charge", "duplicate transaction"

Query: "payment idempotency duplicate transaction race condition mutex retry"
```

### Query with specific keywords

| Task Type | Understand First | Then Query With |
|-----------|------------------|-----------------|
| Bug fix | Error message, symptoms | `"canonical error name component pattern race condition"` |
| Feature | User's description | `"domain terms design patterns architectural concepts"` |
| Test fix | Read the test file | `"API names assertion patterns test utilities"` |
| Architecture | System area | `"component relationships boundaries dependencies"` |

**Bad:** `"authentication"` (too vague)
**Good:** `"JWT refresh token expiration session lifecycle OAuth flow"` (definition-style)

### Use Cog results

- Follow paths Cog reveals
- Read components Cog mentions first
- Heed gotchas Cog warns about
- If Cog is wrong, correct it immediately with `cog_update`

---

## Recording Rules

### CRITICAL: Chains vs Associations

**Before recording, ask: Is this sequential or hub-shaped?**

| Structure | Use | Example |
|-----------|-----|---------|
| **Sequential** (A -> B -> C) | `chain_to` | Technology enables Pattern enables Feature |
| **Hub** (A, B, C all connect to X) | `associations` | Meeting connects to Participants, Outcomes |

**Default to chains** for:
- Technology dependencies (DB -> ORM -> API)
- Causal sequences (Cause -> Effect -> Consequence)
- Architectural decisions (ADR -> Technology -> Feature)
- Enabling relationships (Infrastructure -> enables -> Capability)
- Reasoning paths (Premise -> implies -> Conclusion)

**Use associations** for:
- Hub/star patterns (one thing connects to many unrelated things)
- Linking to existing concepts in the graph
- Multi-party contexts (meetings, decisions with stakeholders)

### Chain Example (PREFERRED for dependencies)

```
cog_learn({
  "term": "PostgreSQL",
  "definition": "Relational database with ACID guarantees",
  "chain_to": [
    {"term": "Ecto ORM", "definition": "Elixir database wrapper with changesets", "predicate": "enables"},
    {"term": "Phoenix Contexts", "definition": "Business logic boundaries in Phoenix", "predicate": "enables"}
  ]
})
```

Creates: PostgreSQL ->[enables]-> Ecto ORM ->[enables]-> Phoenix Contexts

### Association Example (for hubs)

```
cog_learn({
  "term": "Auth Review 2024-01-20",
  "definition": "Decided JWT with refresh tokens. Rejected session cookies.",
  "associations": [
    {"target": "JWT Pattern", "predicate": "leads_to"},
    {"target": "Session Cookies", "predicate": "contradicts"},
    {"target": "Mobile Team", "predicate": "is_component_of"}
  ]
})
```

Creates hub: JWT Pattern <-[leads_to]<- Auth Review ->[contradicts]-> Session Cookies

---

### When to record (during work)

At these checkpoints, ask: *"What did I just learn that I didn't know 5 minutes ago?"*

| Checkpoint | Record |
|------------|--------|
| After identifying root cause | Why it was broken |
| After reading surprising code | The non-obvious behavior |
| After a failed attempt | Why it didn't work |
| Before implementing fix | The insight (freshest now) |
| After discovering connection | The relationship |
| After a meeting or decision | The context hub linking participants and outcomes |
| After researching/exploring architecture | System limits, configuration points, component boundaries |

**Record immediately.** Don't wait until task end -- you'll forget details.

### Before calling `cog_learn`

1. **Decide: chain or hub?** (see above)
2. **For chains**: Build the sequence of steps with `chain_to`
3. **For hubs**: Identify association targets from source material or Cog query

**Skip the query when:**
- Source material explicitly names related concepts (ADRs, documentation, structured data)
- You already know target terms from conversation context
- The insight references specific concepts by name

**Query first when:**
- Recording an insight and unsure what it relates to
- Source is vague about connections
- Exploring a new domain with unknown existing concepts

### After calling `cog_learn`

The operation is complete. **Do NOT verify your work by:**
- Calling `cog_recall` to check the engram exists
- Calling `cog_connections` to verify associations were created
- Calling `cog_trace` to see if paths formed

Trust the response confirmation. Verification wastes turns and adds no value -- if the operation failed, you'll see an error.

### Recording Efficiency

**One operation = one tool call.** Use `chain_to` for sequences, `associations` for hubs.

**Never** follow `cog_learn` with separate `cog_associate` calls -- put all relationships in the original call.

### Writing good engrams

**Terms (2-5 words):**
- "Session Token Refresh Timing"
- "Why We Chose PostgreSQL"
- NOT "Architecture" (too broad)
- NOT "Project Overview" (super-hub)

**Definitions (1-3 sentences):**
1. What it is
2. Why it matters / consequences
3. Related keywords for search

**Never create super-hubs** -- engrams so generic everything connects to them (e.g., "Overview", "Main System"). They pollute search results.

### Relationship predicates

| Predicate | Meaning | Best for | Use in |
|-----------|---------|----------|--------|
| `enables` | A makes B possible | Tech dependencies | **chain_to** |
| `requires` | A is prerequisite for B | Dependencies | **chain_to** |
| `implies` | If A then B | Logical consequences | **chain_to** |
| `leads_to` | A flows to B | Outcomes, consequences | **chain_to** |
| `precedes` | A comes before B | Sequencing, timelines | **chain_to** |
| `derived_from` | A is based on B | Origins | **chain_to** |
| `contradicts` | A and B mutually exclusive | Rejected alternatives | associations |
| `is_component_of` | A is part of B | Parts to whole | associations |
| `contains` | A includes B | Whole to parts | associations |
| `example_of` | A demonstrates pattern B | Instances of patterns | associations |
| `generalizes` | A is broader than B | Abstract concepts | associations |
| `supersedes` | A replaces B | Deprecations | associations |
| `similar_to` | A and B are closely related | Related approaches | associations |
| `contrasts_with` | A is alternative to B | Different approaches | associations |
| `related_to` | General link (use sparingly) | When nothing else fits | associations |

**Chain predicates** (`enables`, `requires`, `implies`, `leads_to`, `precedes`, `derived_from`) express **flow** -- use them in `chain_to` to build traversable paths.

### Modeling Complex Contexts (Hub Node Pattern)

Synapses are binary (one source, one target). For multi-party relationships, use a **hub engram** connecting all participants.

#### When to use hub nodes

| Scenario | Hub Example | Connected Concepts |
|----------|-------------|-------------------|
| Meeting with outcomes | "Q1 Planning 2024-01" | Participants, decisions |
| Decision with stakeholders | "Decision: Adopt GraphQL" | Pros, cons, voters |
| Feature with components | "User Auth Feature" | OAuth, session, UI |
| Incident with timeline | "2024-01 Payment Outage" | Cause, systems, fix |

---

## Consolidation (MANDATORY)

**Every task must end with consolidation.** Short-term memories decay in 24 hours.

### After work is complete:

```
cog_list_short_term({"limit": 20})
```

For each memory:
- **Valid and useful?** -> `cog_reinforce` (makes permanent)
- **Wrong or not useful?** -> `cog_flush` (deletes)

### When to reinforce immediately

- Insights from code you just wrote (you know it's correct)
- Gotchas you just hit and fixed
- Patterns you just applied successfully

### When to wait for validation

- Hypotheses about why something is broken
- Assumptions about unfamiliar code
- Solutions you haven't tested

---

## Verification (Prevents Staleness)

Synapses decay if not verified as still semantically accurate.

### When to verify

- After using `cog_trace` and confirming paths are correct
- When reviewing `cog_connections` and relationships hold
- After successfully using knowledge from a synapse

### Staleness levels

| Level | Months Unverified | Score | Behavior |
|-------|-------------------|-------|----------|
| Fresh | < 3 | 0.0-0.49 | Normal |
| Warning | 3-6 | 0.5-0.79 | Appears in `cog_stale` |
| Critical | 6+ | 0.8-0.99 | Penalty in path scoring |
| Deprecated | 12+ | 1.0 | Excluded from spreading activation |

### Periodic maintenance

Run `cog_stale({"level": "all"})` periodically to review relationships that may have become outdated. For each stale synapse:

- **Still accurate?** -> `cog_verify` to reset staleness
- **No longer true?** -> `cog_unlink` to remove

---

## Validation & Correction

### Cog is hints, not truth

Always verify against current code. If Cog is wrong:

| Scenario | Action |
|----------|--------|
| Minor inaccuracy | `cog_update` to fix |
| Pattern changed significantly | Unlink old, create new engram |
| Completely obsolete | Update to note "DEPRECATED: [reason]" |

---

## Subagents

Subagents MUST query Cog before exploring. Same rules apply:
1. Understand task
2. **Reformulate query to definition-style**
3. Query Cog with reformulated keywords
4. Wait for results
5. Then explore

---

## Summary Reporting

Only mention Cog when relevant:

| Condition | Include |
|-----------|---------|
| Cog helped | `**Cog helped by:** [specific value]` |
| Memories created | `**Recorded to Cog:** [term names]` |
| Cog not used | Nothing (don't mention Cog) |
| Cog queried but unhelpful | Don't mention the empty query, but **still record** new knowledge you discovered through exploration |

---

## Never Store

- Passwords, API keys, tokens, secrets
- SSH/PGP keys, certificates
- Connection strings with credentials
- PII (emails, SSNs, credit cards)
- `.env` file contents

Server auto-rejects sensitive content.

---

## Limitations

- **No engram deletion** -- use `cog_update` or `cog_unlink`
- **No multi-query** -- chain manually
- **One synapse per direction** -- repeat calls strengthen existing link

---

## Spreading Activation

`cog_recall` returns:
1. **Seeds** -- direct matches
2. **Paths** -- engrams connecting seeds (built from chains!)
3. **Synapses** -- relationships along paths

This surfaces the "connective tissue" between results. **Chains create these traversable paths.**
