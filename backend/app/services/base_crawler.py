#!/usr/bin/env python3



class BaseCrawler:
    base_url: str

    def search_novels(self, keyword: str) -> list[dict]:
        raise NotImplementedError

    def get_chapter_list(self, novel_url: str) -> list[dict]:
        raise NotImplementedError

    def get_chapter_content(self, chapter_url: str) -> dict:
        raise NotImplementedError
