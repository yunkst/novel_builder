#!/usr/bin/env python3
# -*- coding: utf-8 -*-

from typing import List, Dict


class BaseCrawler:
    base_url: str

    def search_novels(self, keyword: str) -> List[Dict]:
        raise NotImplementedError

    def get_chapter_list(self, novel_url: str) -> List[Dict]:
        raise NotImplementedError

    def get_chapter_content(self, chapter_url: str) -> Dict:
        raise NotImplementedError