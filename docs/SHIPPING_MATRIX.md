# SHIFT deployment and platform matrix

Engineering target: Android debug testing first, iOS code maintained in parallel. Final Android vs dual-platform launch sequence must be approved by product owner.

| Component | Local/QA | Production |
|---|---|---|
| Supabase | Separate QA project (not yet provisioned) | SHIFT project `axgzpbtnqhuytlsanyto` |
| Flutter | Reproducible SDK pinned by CI; no user secret | Signed release with stable package/bundle ID |
| Google Auth | Separate OAuth test redirects and signing SHA | Production client ID, SHA and provider consent |
| Meta | Development app with eligible test Page/pro account | Approved scopes and app review |
| AI | Restricted provider test key and quota | Server-secret provider credentials with budgets |
| Search | Restricted test key and licensing check | Server-secret provider key, provenance and rate limits |
| Publishing | No real account without explicit test authorization | User-authorized accounts, exact revision approval |
| Observability | Synthetic data and redacted logs | Metrics, privacy retention, incident alarms |

Release builds must include the correct public Supabase URL/key but never service-role keys, AI/Meta secrets or signing private keys. Do not install production builds with QA OAuth callbacks or register app-store records under throwaway package IDs.
