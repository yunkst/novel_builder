import os
import sys

# Ensure parent directory is in module search path
CURRENT_DIR = os.path.dirname(os.path.abspath(__file__))
PARENT_DIR = os.path.dirname(CURRENT_DIR)
if PARENT_DIR not in sys.path:
    sys.path.insert(0, PARENT_DIR)

from alice_sw_crawler import AliceSWCrawler


def main():
    crawler = AliceSWCrawler()
    query = "斗罗"
    print("Query:", query)

    try:
        results = crawler.search_novels(query)
    except Exception as e:
        print("Search error:", e)
        sys.exit(1)

    print("Results:", len(results))
    for i, r in enumerate(results[:5]):
        print(i, r.get('title', ''), r.get('url', ''))

    if not results:
        print("No search results")
        sys.exit(1)

    first = results[0]
    print("First:", first.get('title', ''), first.get('url', ''))

    try:
        chapters = crawler.get_chapter_list(first['url'])
    except Exception as e:
        print("Chapter list error:", e)
        sys.exit(1)

    print("Chapters:", len(chapters))
    for ch in chapters[:20]:
        print(" -", ch.get('title', ''), ch.get('url', ''))

    book_chapters = [ch for ch in chapters if '/book/' in ch.get('url', '')]
    print("Book chapters:", len(book_chapters))

    target = book_chapters[0]['url'] if book_chapters else None
    print("Target:", target)

    if target:
        try:
            content = crawler.get_chapter_content(target)
        except Exception as e:
            print("Content error:", e)
            sys.exit(1)
        print("Content length:", len(content))
        print("Content sample:\n" + content[:500])
    else:
        print("No chapter content URL found")


if __name__ == "__main__":
    main()