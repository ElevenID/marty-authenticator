# Deep Linking Quick Reference

## Supported URL Schemes

### Token Import

- `otpauth://` - Standard OTP URLs
- `otpauth-migration://` - Google Authenticator migration
- `pia://` - privacyIDEA tokens and QR backups

### OID4VC (OpenID for Verifiable Credentials)

- `openid-credential-offer://` - Credential issuance
- `openid4vp://` - Presentation requests
- `openid-credential://` - Direct credential imports

### Navigation

- `homewidgetnavigate://` - Widget-based navigation

## Quick Examples

### Receive a Credential

```
openid-credential-offer://?credential_offer=eyJ0eXAiOiJKV1Q...
```

User taps link → App opens → Credential offer displayed → User accepts → Credential stored

### Present Credentials

```
openid4vp://?request=eyJ0eXAiOiJKV1Q...&callback=https://verifier.com/result
```

User taps link → App opens → Shows required credentials → User authorizes → Returns to verifier

### Import Traditional Token

```
otpauth://totp/Example:user@example.com?secret=JBSWY3DPEHPK3PXP&issuer=Example
```

User taps/scans → App opens → Token imported automatically

## Architecture

```
Deep Link → DeeplinkNotifier → Scheme Processor → Token/Credential Action
```

## Key Benefits

- **Instant Setup**: No manual credential entry
- **Seamless UX**: Direct app-to-app workflows
- **Standardized**: Works with any OID4VC-compatible system
- **Secure**: Cryptographic verification built-in
- **Private**: Selective disclosure control

For detailed documentation see [DEEP_LINKING.md](./DEEP_LINKING.md).
