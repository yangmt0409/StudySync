# Firebase Architecture Notes

## Project Info
- **Firebase Project**: StudySync
- **Project ID**: studysync-3bbd8
- **Project Number**: 62468094120
- **Bundle ID**: PlumsXD.StudySync

## Authentication Providers
- Apple Sign-In (enabled)
- Email/Password (enabled)

## Known Issue: China Mainland Access

Firebase (Google infrastructure) may be slow or unreachable in mainland China without VPN.

### Current Flow (all paths go through Google servers)
```
Apple ID Login → Apple servers (OK in China) → Firebase Auth (Google) ⚠️
Email Login → Firebase Auth (Google) ⚠️
Firestore R/W → Google servers ⚠️
```

### Mitigation Plan (implement when needed)
If users in China report connectivity issues, add **Cloudflare Workers** as a proxy:

1. Create a Cloudflare Worker that proxies requests to Firebase endpoints:
   - `identitytoolkit.googleapis.com` (Auth)
   - `firestore.googleapis.com` (Database)
2. Point the app's Firebase config to the Cloudflare Worker URL
3. Cloudflare has edge nodes in China, so requests will be routed properly

**Alternative long-term options:**
- Supabase (Singapore region) - better Asia latency
- LeanCloud - China-native, no proxy needed
- Self-hosted backend with server in Hong Kong/Singapore

### Priority
Low - target users are international students studying abroad (normal internet access).
Only address if user feedback indicates China access problems.
