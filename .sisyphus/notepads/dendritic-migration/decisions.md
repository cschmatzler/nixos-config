
- Do not include user aspects (e.g. `den.aspects.cschmatzler`) in host aspect `includes`. Den HM integration already applies the user aspect for each `den.hosts.<system>.<host>.users.<user>` via `den.ctx.user`; duplicating it via host `includes` leads to duplicated HM option merges (notably `types.lines` options like `programs.nushell.extraConfig`).
