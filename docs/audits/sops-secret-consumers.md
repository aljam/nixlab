| Secret | Consumer | Follow-up |
|---|---|---|
| User passwords | `aljam_password` is consumed through `hashedPasswordFile`. | Confirm whether a password change requires a consumer restart or qualifies for an exemption. |
| Mail | `smtp_relay_password` restarts Postfix; `mail_password_aljam` restarts Dovecot. | Implemented. |
| Monitoring | `grafana-admin-password` and `grafana-secret-key` restart Grafana; `nfty-url` restarts the ntfy alert relay. | Implemented. |
| Database | `pgadmin_password` restarts pgAdmin. | Implemented. |
| NAS | `nas-credentials` is consumed by the NAS mount. | Exempted as a one-shot mount credential; remount manually after rotating credentials. |
| Servarr | `radarr_api_key` restarts Recyclarr. | Implemented. |
