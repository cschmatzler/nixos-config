---
description: Review code changes (working-copy, bookmark, change, PR, or folder)
agent: review
subtask: true
---

Review the following code changes. $ARGUMENTS

Current repository state:

```
!`jj log -r '::@ ~ ::trunk()' -n 15 --no-graph -T 'change_id.shortest(8) ++ " " ++ coalesce(bookmarks, "") ++ " " ++ description.first_line() ++ "\n"' 2>/dev/null || echo "Not a jj repository or no divergence from trunk"`
```

Working copy status:

```
!`jj diff --summary 2>/dev/null || echo "No working-copy changes"`
```

Available bookmarks:

```
!`jj bookmark list --all-remotes -T 'name ++ if(remote, "@" ++ remote, "") ++ "\n"' 2>/dev/null | head -20 || echo "No bookmarks"`
```
