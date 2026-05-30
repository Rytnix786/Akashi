"""
Akashi — Supabase Direct REST Client
==================================
Handles all database operations via Supabase REST (PostgREST) and Auth (GoTrue) APIs.
Uses direct async HTTP calls with `httpx` to bypass package dependency crashes
on Python 3.14, ensuring maximum reliability and performance.

Reference: Akashi MVP Spec v1.0, Section 4 & 5
"""

import os
import logging
from typing import Any, Dict, List, Optional, Union
import httpx
from dotenv import load_dotenv

logger = logging.getLogger("akashi.db")

class SupabaseClient:
    """
    Lightweight, high-performance async client for Supabase REST API.
    Bypasses row-level security (RLS) by using the service role key for administrative operations.
    """
    def __init__(self, url: Optional[str] = None, service_key: Optional[str] = None):
        load_dotenv()
        self.url = url or os.getenv("SUPABASE_URL", "")
        self.service_key = service_key or os.getenv("SUPABASE_SERVICE_KEY", "")

        if not self.url or not self.service_key:
            logger.error("Supabase URL or Service Key is missing in environment variables.")

        # Clean trailing slashes from URL
        self.url = self.url.rstrip("/")
        
        # Base headers for PostgREST
        self.headers = {
            "apikey": self.service_key,
            "Authorization": f"Bearer {self.service_key}",
            "Content-Type": "application/json",
            "Prefer": "return=representation"  # Returns inserted/updated rows
        }

    async def _request(
        self,
        method: str,
        path: str,
        json_data: Optional[Union[Dict, List]] = None,
        params: Optional[Dict[str, Any]] = None,
        custom_headers: Optional[Dict[str, str]] = None
    ) -> httpx.Response:
        """Sends an async HTTP request to Supabase API endpoints."""
        url = f"{self.url}{path}"
        headers = {**self.headers, **(custom_headers or {})}

        async with httpx.AsyncClient(timeout=30.0) as client:
            try:
                response = await client.request(
                    method=method,
                    url=url,
                    headers=headers,
                    params=params,
                    json=json_data
                )
                response.raise_for_status()
                return response
            except httpx.HTTPStatusError as e:
                logger.error(f"HTTP error {e.response.status_code} requesting {method} {path}: {e.response.text}")
                raise e
            except Exception as e:
                logger.error(f"Network error requesting {method} {path}: {str(e)}")
                raise e

    # ─── Auth Operations (GoTrue API) ─────────────────────────────────────────
    
    async def send_otp(self, phone: str) -> Dict[str, Any]:
        """
        Send a one-time SMS OTP to a phone number.
        Spec Reference: Screen 2 / Screen 3, POST /auth/otp/send
        """
        logger.info(f"Sending OTP to {phone}")
        # Supabase signup/login OTP endpoint
        path = "/auth/v1/otp"
        payload = {
            "phone": phone,
            "create_user": True  # Automatically sign up if not registered
        }
        response = await self._request("POST", path, json_data=payload)
        return response.json()

    async def verify_otp(self, phone: str, token: str) -> Dict[str, Any]:
        """
        Verify the SMS OTP and return a JWT access token.
        Spec Reference: Screen 3, POST /auth/otp/verify
        """
        logger.info(f"Verifying OTP for {phone}")
        path = "/auth/v1/verify"
        payload = {
            "phone": phone,
            "token": token,
            "type": "sms"
        }
        response = await self._request("POST", path, json_data=payload)
        return response.json()

    # ─── Database Operations (PostgREST API) ──────────────────────────────────

    async def select(
        self,
        table: str,
        select_fields: str = "*",
        filters: Optional[Dict[str, str]] = None,
        order_by: Optional[str] = None,
        limit: Optional[int] = None
    ) -> List[Dict[str, Any]]:
        """
        Perform a SELECT query.
        Example: select("farmers", filters={"phone": "eq.+88017..."})
        """
        path = f"/rest/v1/{table}"
        params = {"select": select_fields}

        if filters:
            for field, filter_clause in filters.items():
                params[field] = filter_clause

        if order_by:
            params["order"] = order_by

        if limit is not None:
            params["limit"] = str(limit)

        response = await self._request("GET", path, params=params)
        return response.json()

    async def insert(self, table: str, data: Union[Dict[str, Any], List[Dict[str, Any]]]) -> List[Dict[str, Any]]:
        """Perform an INSERT query."""
        path = f"/rest/v1/{table}"
        response = await self._request("POST", path, json_data=data)
        return response.json()

    async def update(self, table: str, data: Dict[str, Any], filters: Dict[str, str]) -> List[Dict[str, Any]]:
        """Perform an UPDATE query."""
        path = f"/rest/v1/{table}"
        params = {}
        for field, filter_clause in filters.items():
            params[field] = filter_clause

        response = await self._request("PATCH", path, json_data=data, params=params)
        return response.json()

    async def delete(self, table: str, filters: Dict[str, str]) -> List[Dict[str, Any]]:
        """Perform a DELETE query."""
        path = f"/rest/v1/{table}"
        params = {}
        for field, filter_clause in filters.items():
            params[field] = filter_clause

        response = await self._request("DELETE", path, params=params)
        return response.json()

    async def rpc(self, function_name: str, params: Optional[Dict[str, Any]] = None) -> Any:
        """Call a Postgres remote procedure call (RPC) / Database Function."""
        path = f"/rest/v1/rpc/{function_name}"
        response = await self._request("POST", path, json_data=params or {})
        return response.json()

# Singleton instance for easy import across services and routes
db = SupabaseClient()
