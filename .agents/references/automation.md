# Cronjobs and automation

Cronjobs:

* Prefer `@reboot` where daily uptime is uncertain
* Scripts must be idempotent
* Scripts must log execution
* Scripts must not assume network availability

Cron scripts live alongside the functionality they support, not in a central cron folder.
