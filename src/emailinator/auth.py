from __future__ import annotations

import os
from abc import ABC, abstractmethod

from .storage import crud


class AuthBackend(ABC):
    """Pluggable authentication backend interface."""

    @abstractmethod
    def authenticate(self, user: str, credential: str) -> bool:
        """Return True if the credential grants access for the user."""
        raise NotImplementedError


class APIKeyAuthBackend(AuthBackend):
    """Authenticate using stored API keys."""

    def authenticate(self, user: str, credential: str) -> bool:  # pragma: no cover - trivial
        return crud.verify_api_key(user, credential)


class OAuthBackend(AuthBackend):
    """Placeholder for future OAuth providers."""

    def authenticate(self, user: str, credential: str) -> bool:  # pragma: no cover - future
        raise NotImplementedError("OAuth authentication not implemented")


def _load_backend() -> AuthBackend:
    """Select the auth backend based on configuration."""

    backend = os.getenv("AUTH_BACKEND", "api_key").lower()
    if backend == "oauth":
        return OAuthBackend()
    return APIKeyAuthBackend()


auth_backend: AuthBackend = _load_backend()
