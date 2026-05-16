#!/usr/bin/env python3
"""
Hermes AI Chat Client.

This module provides a client for interacting with Hermes AI API Server,
supporting streaming responses and tool execution.
"""

import logging
from collections.abc import AsyncGenerator
from typing import Any

import httpx

from ..config import settings

logger = logging.getLogger(__name__)


class HermesClient:
    """
    Hermes API Client for chat completions with streaming support.

    This client forwards requests to Hermes API Server and streams
    responses back to the caller.
    """

    def __init__(self):
        """Initialize the Hermes client with configured settings."""
        raw_url = settings.hermes_api_url
        self.api_url = raw_url.rstrip("/") if raw_url else ""
        self.api_key = settings.hermes_api_key
        self.timeout = settings.hermes_timeout

    @property
    def is_configured(self) -> bool:
        """Check if Hermes API is properly configured."""
        return bool(self.api_url and self.api_key)

    def get_headers(self) -> dict[str, str]:
        """Get HTTP headers for API requests."""
        headers = {
            "Content-Type": "application/json",
        }
        if self.api_key:
            headers["Authorization"] = f"Bearer {self.api_key}"
        return headers

    async def chat_completions_stream(
        self, payload: dict[str, Any]
    ) -> AsyncGenerator[bytes, None]:
        """
        Send a chat completion request with streaming response.

        Args:
            payload: The request payload containing messages and parameters.

        Yields:
            Raw SSE bytes from the Hermes API response.

        Raises:
            ValueError: If Hermes API is not configured.
            httpx.HTTPStatusError: If the API returns an error status.
        """
        if not self.is_configured:
            raise ValueError(
                "Hermes API is not configured. "
                "Please set HERMES_API_URL and HERMES_API_KEY."
            )

        url = f"{self.api_url}/v1/chat/completions"

        logger.info("Sending streaming request to Hermes API: %s", url)

        async with httpx.AsyncClient(timeout=self.timeout) as client:
            try:
                async with client.stream(
                    "POST",
                    url,
                    headers=self.get_headers(),
                    json=payload,
                ) as response:
                    if response.status_code != 200:
                        error_text = await response.aread()
                        decoded = error_text.decode("utf-8", errors="replace")
                        logger.error(
                            "Hermes API error: %s - %s",
                            response.status_code,
                            decoded,
                        )
                        response.raise_for_status()

                    async for chunk in response.aiter_bytes():
                        if chunk:
                            yield chunk

            except httpx.TimeoutException:
                logger.error("Hermes API request timed out")
                raise
            except httpx.HTTPError as e:
                logger.error("Hermes API HTTP error: %s", e)
                raise

    async def health_check(self) -> dict[str, Any]:
        """
        Check the health status of Hermes API.

        Returns:
            dict with status information.
        """
        if not self.is_configured:
            return {
                "status": "unconfigured",
                "message": "Hermes API URL or key not configured",
                "configured": False,
            }

        try:
            # Try to reach the health endpoint if available
            health_url = f"{self.api_url}/health"
            async with httpx.AsyncClient(timeout=10) as client:
                response = await client.get(health_url, headers=self.get_headers())
                if response.status_code == 200:
                    return {
                        "status": "healthy",
                        "message": "Hermes API is accessible",
                        "configured": True,
                    }
                return {
                    "status": "unhealthy",
                    "message": f"Hermes API returned status {response.status_code}",
                    "configured": True,
                }
        except httpx.TimeoutException:
            return {
                "status": "timeout",
                "message": "Hermes API health check timed out",
                "configured": True,
            }
        except httpx.HTTPError:
            # Health endpoint might not exist, try a simple API test
            return {
                "status": "unknown",
                "message": "Hermes API endpoint not reachable, but configured",
                "configured": True,
            }
        except Exception as e:
            return {
                "status": "error",
                "message": str(e),
                "configured": True,
            }


# Global singleton instance
hermes_client = HermesClient()


def get_hermes_client() -> HermesClient:
    """Get the global Hermes client instance."""
    return hermes_client
