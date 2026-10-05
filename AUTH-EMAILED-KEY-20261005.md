# LiDAR-Knight Auth 4.4.30 — emailed admin keys (modification notice, 5 October 2026)

Modified by ARCHITECTURE (LiDAR Knight) on top of 4.4.29 (`2bacc50`), under the AGPL-3.0 licence of Ente Auth.

- **Format-2 admin key import.** `IMPORT MASTER KEY .ENV` accepts the emailed individual key file (`LK_FORMAT=2`: issuer, seat,
  name, email, generation, issue/activation times, activation id, TOTP secret, otpauth URI) in addition to the unchanged
  four-field format-1 file. The parser accepts and refuses exactly what the LiDAR Knight server's reference parser does.
- **Activation.** A format-2 card starts PENDING and is activated with the official server
  (`https://admin.lidarknight.com/api/owner/activate`, pinned, HTTPS only, no redirects) using its current code. States:
  PENDING, ACTIVE, REFUSED (reason), EXPIRED, FAILED, REISSUED, REVOKED, and a transient PENDING SETUP for a newer key.
- **Replacement.** A recoverable card is replaced only by a key the server proved active for the same seat; an active
  card or a format-1 master card keeps the linked-credential rule. A local import is never shown as a sign-in.
- Format-1 files, standard accounts, the compact black design and the AUTH branding are unchanged.
- No credential, key, code or provider secret is part of this source. Tests use synthetic keys only.
