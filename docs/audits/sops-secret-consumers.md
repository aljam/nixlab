| Secret | Consumer | Follow-up |
|---|---|---|
| User passwords | `aljam_password` is consumed through `hashedPasswordFile`. | Confirm whether a password change requires a consumer restart or qualifies for an exemption. |
| Mail | `smtp_relay_password` and `mail_password_aljam` are root-owned mail credentials. | Identify the exact mail service units that consume them and add restart/reload consumers or exemptions. |
| Monitoring | `grafana-admin-password`, `grafana-secret-key`, and `nfty-url` are consumed by Grafana and alerting. | Add the appropriate Grafana/alerting restart or reload units. |
| Database | `pgadmin_password` is consumed by pgAdmin. | Add the pgAdmin consumer unit or an exemption if it is provisioned only during initialization. |
| NAS | `nas-credentials` is consumed by the NAS mount. | Add the mount unit as a restart consumer or exempt it as a one-shot mount credential. |
| Servarr | `radarr_api_key` is consumed by Recyclarr. | Add the Recyclarr consumer unit. |
