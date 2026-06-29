# Pre-Apply and Post-Apply Scripts Blocks

`pre_apply_scripts` and `post_apply_scripts` collect script paths or commands
for the configuration model.

```i3
pre_apply_scripts {
  "./scripts/check-prereqs.sh"
}

post_apply_scripts {
  "./scripts/verify.sh"
}
```

Both blocks accept either bare command arguments or assignment values. Non-empty
values are appended in declaration order.

```i3
pre_apply_scripts {
  first = "./scripts/bootstrap.sh"
  "./scripts/check-prereqs.sh"
}
```

Use the [`script`](script.md) action block when you need normal action
execution, events, lockfile records, and rollback integration.
