## 2026-03-30 - Prevent Information Disclosure in UI Error Messages
**Vulnerability:** Raw exception messages ($e) were exposed directly in user-facing UI elements (loading screens and SnackBar notifications).
**Learning:** Exposing detailed exception objects or stack traces in client-facing UI can leak internal implementation details, file paths, or third-party service details to end users.
**Prevention:** Always log full exception details using `debugPrint` or a secure logger, and display sanitized, generic, user-friendly error messages in the UI.
