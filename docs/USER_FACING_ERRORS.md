# SHIFT — user-facing error and recovery catalog

Never display service keys, stack traces, internal SQL/HTTP request bodies, user IDs, or provider tokens. Avoid promising a save when no cloud acknowledgement was received.

| Condition | Message | Recovery |
|---|---|---|
| Missing/expired login | Sign in to sync your work. | Reauthenticate; keep unsent local edits separate |
| Email verification pending | Check your inbox to verify your address. | Resend from verification screen after cooldown |
| No network | You're offline. Changes on this device haven't synced yet. | Retry after reconnect; don't navigate away from unsaved draft |
| Draft save conflict | This draft changed on another device. Review the latest version before saving. | Fetch current version; preserve original locally |
| Image too large | This image exceeds the upload limit. | Compress or pick a smaller image |
| Unsupported media | This image format isn't supported for the selected destination. | Choose a valid file |
| AI not configured | Content generation isn't available yet. | Try manual drafting or contact service owner |
| AI quota exceeded | Your generation limit has been reached. | Show remaining quota/reset date when real |
| Research unavailable | Live research isn't available right now. | Retry later or add source URL manually |
| OAuth missing/revoked | Reconnect this account to authorize publishing. | Official provider OAuth |
| Pending review | Your post hasn't been approved for publishing. | Submit exact current version |
| Approval superseded | The draft changed after approval and needs a new review. | Review changed version |
| Scheduled but not confirmed | This post is queued, not yet published. | Show job history and next check |
| Unknown provider publish outcome | We couldn't confirm whether the provider published this post. | Hold and reconcile; avoid duplicate |
| Post failed | Publishing failed. Check the destination and try again safely. | Diagnose provider response; controlled retry |
| Subscription pending | We can't confirm your purchase yet. | Restore purchases, never invent entitlement |
| Account deletion requested | Your request was received; deletion status will appear here. | Server audit and policy-based completion |

UI checklist: idle / loading / empty / content / error states for every network screen; accessible retry; clear local-vs-cloud labels; no blocking full-screen spinners for routine refresh; truthful feature capability messages.
