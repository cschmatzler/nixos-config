# Estimation

## Why Estimates Fail

| Cause | Mitigation |
|-------|------------|
| Optimism bias | Use historical data, not gut |
| Missing scope | List "obvious" tasks explicitly |
| Integration blindness | Add 20-30% for glue code |
| Unknown unknowns | Add buffer based on novelty |
| Interruptions | Assume 60% focused time |

## Estimation Techniques

### Three-Point Estimation
```
Expected = (Optimistic + 4xMostLikely + Pessimistic) / 6
```

### Relative Sizing
Compare to known references:
- "This is about twice as complex as Feature X"
- Use Fibonacci (1, 2, 3, 5, 8, 13) to reflect uncertainty

### Task Decomposition
1. Break into tasks <=4 hours
2. If can't decompose, spike first
3. Sum tasks + 20% integration buffer

## Effort Multipliers

| Factor | Multiplier |
|--------|------------|
| New technology | 1.5-2x |
| Unclear requirements | 1.3-1.5x |
| External dependencies (waiting on others) | 1.2-1.5x |
| Legacy/undocumented code | 1.3-2x |
| Production deployment | 1.2x |
| First time doing X | 2-3x |
| Context switching (other priorities) | 1.3x |
| Yak shaving risk (unknown unknowns) | 1.5x |

## Hidden Work Checklist

Always include time for:
- [ ] Code review (20% of dev time)
- [ ] Testing (30-50% of dev time)
- [ ] Documentation (10% of dev time)
- [ ] Deployment/config (varies)
- [ ] Bug fixes from testing (20% buffer)
- [ ] Interruptions / competing priorities

## When to Re-Estimate

Re-estimate when:
- Scope changes materially
- Major unknown becomes known
- Actual progress diverges >30% from estimate

## Communicating Estimates

**Good:** "1-2 weeks, confidence 70%-main risk is the third-party API integration"

**Bad:** "About 2 weeks"

Always include:
1. Range, not point estimate
2. Confidence level
3. Key assumptions/risks
