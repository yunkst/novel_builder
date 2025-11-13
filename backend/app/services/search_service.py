#!/usr/bin/env python3

from typing import Any

from .base_crawler import BaseCrawler


class SearchService:
    def __init__(self, crawlers: list[BaseCrawler] | None = None):
        self.crawlers = crawlers or []

    async def search(
        self, keyword: str, crawlers: dict[str, Any] | None = None
    ) -> list[dict[str, Any]]:
        """
        Search for novels using provided crawlers.

        Args:
            keyword: Search keyword
            crawlers: Dictionary of crawlers to use (overrides instance crawlers)

        Returns:
            List of search results
        """
        if not keyword or len(keyword.strip()) < 2:
            return []

        # Use provided crawlers or instance crawlers
        target_crawlers = crawlers or {}
        results: list[dict[str, Any]] = []

        for site_name, crawler in target_crawlers.items():
            try:
                # Check if crawler has search method (uses search_novels as per BaseCrawler spec)
                if hasattr(crawler, "search_novels") and callable(crawler.search_novels):
                    items = await crawler.search_novels(keyword)
                    if items:
                        results.extend(items)
            except Exception as e:
                # Log error but continue with other crawlers
                print(f"Error searching with {site_name}: {e}")
                continue

        # Normalize and deduplicate results
        seen = set()
        unique_results: list[dict[str, Any]] = []

        for result in results:
            if isinstance(result, dict):
                # Ensure required fields exist
                title = result.get("title", "")
                url = result.get("url", "")
                author = result.get("author", "未知作者")

                # Create unique key
                key = (title.strip(), url.strip())

                # Add if valid and not seen
                if title and url and key not in seen:
                    unique_results.append(
                        {
                            "title": title.strip(),
                            "author": author.strip(),
                            "url": url.strip(),
                            "cover_url": result.get("cover_url", ""),
                            "description": result.get("description", ""),
                            "status": result.get("status", "unknown"),
                            "last_updated": result.get("last_updated", ""),
                        }
                    )
                    seen.add(key)

        return unique_results
