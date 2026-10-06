# LiDAR-Knight Auth 4.4.31: update notice, one-key admin card, installer art (modification notice, 6 October 2026)

Modified by ARCHITECTURE (LiDAR Knight) on top of 4.4.30 (`ceb583a`), under the AGPL-3.0 licence of Ente Auth.

- **Update notice.**
  - On start and every six hours the app reads `https://lidarknight.com/auth/update.json`: pinned host, HTTPS only, no cookies, no identity, no redirects, at most 4 KiB.
  - Only when a strictly newer version is published, a red arrow appears right of the menu. Hovering it (or a long press) shows ONLY the admin's message, one plain paragraph of at most 280 characters with no title. A click opens an https page on lidarknight.com.
  - Nothing shows when up to date or offline.
- **LIDAR ADMIN card.**
  - One key slot: a new import becomes the pending replacement in the same card, replacing it only after the server proves activation; CANCEL drops it.
  - REMOVE with a two-step confirm, which removes the key from this device only.
  - A BROKEN state for failed, expired, revoked and replaced keys, with the code hidden.
  - ACTIVATE is the primary button while a key is pending or refused. Helper text is trimmed.
- **Import messages.** An encoded (base64) file and a key in a newer format get a clear message. The parser itself is unchanged and still accepts and refuses exactly what the LiDAR Knight server's reference parser does.
- **Setup.** The LiDAR Knight banner on the "Ready to Install" page and the emblem as Setup's small image. Same AppId, upgrades in place.
- No credential, key, code or provider secret is part of this source. Tests use synthetic keys only.
