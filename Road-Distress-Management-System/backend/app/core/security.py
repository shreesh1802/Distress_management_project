"""
Security operations module for the Road Distress Management System.
Password hashing/verification (PBKDF2-HMAC-SHA256) and e-mail normalisation.

Stored hash formats
-------------------
* current: ``pbkdf2_sha256$<iterations>$<salt_hex>$<hash_hex>``
* legacy:  ``<salt_hex>$<hash_hex>`` (100,000 iterations) -- still verified
* anything else (including the unusable-password marker ``"!"`` and the old
  plaintext/placeholder values) is REJECTED: there is no plaintext fallback.
"""

import hashlib
import hmac
import os

# OWASP 2023 guidance for PBKDF2-HMAC-SHA256.
PBKDF2_ITERATIONS = 600_000
_LEGACY_ITERATIONS = 100_000
_SCHEME = "pbkdf2_sha256"

# Stored for accounts that must never be usable with a password (OTP-only
# bootstrap admin, demo placeholders). verify_password() always rejects it.
UNUSABLE_PASSWORD = "!"


def normalize_email(email: str | None) -> str:
    """Canonical form used for every lookup/insert/OTP key: stripped + lower-cased."""
    return (email or "").strip().lower()


def _pbkdf2(password: str, salt: bytes, iterations: int) -> str:
    return hashlib.pbkdf2_hmac("sha256", password.encode("utf-8"), salt, iterations).hex()


def verify_password(plain_password: str, hashed_password: str) -> bool:
    """
    Verify a plain text password against its PBKDF2 hash (constant-time compare).
    Returns False for any value that is not a well-formed hash.
    """
    try:
        if not hashed_password or not isinstance(hashed_password, str):
            return False
        parts = hashed_password.split("$")
        if len(parts) == 4 and parts[0] == _SCHEME:
            iterations = int(parts[1])
            salt_hex, hash_hex = parts[2], parts[3]
            if not (1 <= iterations <= 10_000_000):
                return False
        elif len(parts) == 2:
            iterations = _LEGACY_ITERATIONS
            salt_hex, hash_hex = parts
        else:
            return False
        salt = bytes.fromhex(salt_hex)
        bytes.fromhex(hash_hex)  # reject non-hex stored values
        computed = _pbkdf2(plain_password, salt, iterations)
        return hmac.compare_digest(computed, hash_hex.lower())
    except Exception:
        return False


def get_password_hash(password: str) -> str:
    """
    Generate a secure password hash using PBKDF2-HMAC-SHA256 with a unique random salt.
    Format: pbkdf2_sha256$iterations$salt_hex$hash_hex
    """
    salt = os.urandom(16)
    return f"{_SCHEME}${PBKDF2_ITERATIONS}${salt.hex()}${_pbkdf2(password, salt, PBKDF2_ITERATIONS)}"


def is_usable_hash(stored) -> bool:
    """True if ``stored`` is a well-formed password hash (not the unusable marker, plaintext or garbage)."""
    try:
        if not stored or not isinstance(stored, str):
            return False
        parts = stored.split("$")
        if len(parts) == 4 and parts[0] == _SCHEME:
            if not (1 <= int(parts[1]) <= 10_000_000):
                return False
            salt_hex, hash_hex = parts[2], parts[3]
        elif len(parts) == 2:
            salt_hex, hash_hex = parts
        else:
            return False
        bytes.fromhex(salt_hex)
        bytes.fromhex(hash_hex)
        return True
    except Exception:
        return False


_dummy_hash_value = None


def dummy_password_hash() -> str:
    """
    A valid hash of a random password, computed once. Login verifies against it when the account does not
    exist or has no usable password, so every branch spends the same PBKDF2 time.
    """
    global _dummy_hash_value
    if _dummy_hash_value is None:
        _dummy_hash_value = get_password_hash(os.urandom(16).hex())
    return _dummy_hash_value
