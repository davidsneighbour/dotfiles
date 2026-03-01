## Add errors and warnings to polybar issue plugin

```bash
./configs/system/polybar/scripts/issues-add.sh --id 1234 --prio 1 --label "issue with gmail" --description "longer description of the issue" --verbose
${DOTFILES_PATH}/configs/system/polybar/scripts/issues-add.sh --id 1234 --label "issue with gmail"
```

* `id` must be unique, items with identical `id` will be updated
* `prio` is by default 1 (error), possible values are 1, 2, 3 (error, warning, note)
* `label` is required and a short notice about the issue
* `description` is markdown description, longtext possible

## Remove errors and warnings from polybar issue plugin

```bash
${DOTFILES_PATH}/configs/system/polybar/scripts/issues-remove.sh --id 1234 
```
