from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import urlsplit


ROOT = Path(__file__).resolve().parent.parent
ASSETS = ROOT / "docs" / "assets"


class Page(HTMLParser):
    def __init__(self, path):
        super().__init__()
        self.elements = []
        self.feed(path.read_text(encoding="utf-8"))

    def handle_starttag(self, tag, attributes):
        self.elements.append((tag, dict(attributes)))


def check(actual, expected, context):
    if actual != expected:
        raise SystemExit(f"{context}: expected {expected!r}, got {actual!r}")


def filenames(page, tag, attribute, predicate):
    return [
        Path(urlsplit(attrs[attribute]).path).name
        for name, attrs in page.elements
        if name == tag and attribute in attrs and predicate(attrs)
    ]


pages = (
    ("index.html", "en", "en", "translation-en-es.webp", "setup-en-es.webp"),
    ("es/index.html", "es", "en", "translation-spanish-interface.webp", "setup-spanish-interface.webp"),
    ("he/index.html", "he", "he", "translation-he-en.webp", "setup-he-en.webp"),
)

for filename, locale, source, translation, setup in pages:
    path = ROOT / "docs" / filename
    page = Page(path)
    for asset in (translation, setup):
        check((ASSETS / asset).is_file(), True, f"{filename} asset {asset}")

    check(
        [attrs.get("lang") for tag, attrs in page.elements if tag == "html"],
        [locale],
        f"{filename} page language",
    )
    check(
        [attrs.get("lang") for tag, attrs in page.elements if tag == "mark" and attrs.get("id") == "example-selection"],
        [source],
        f"{filename} example language",
    )
    check(
        filenames(page, "img", "src", lambda a: Path(a["src"]).name.startswith("translation-")),
        [translation],
        f"{filename} translation screenshot",
    )
    check(
        filenames(page, "img", "src", lambda a: "settings-shot" in a.get("class", "").split()),
        [setup],
        f"{filename} setup screenshot",
    )
    check(
        filenames(page, "meta", "content", lambda a: a.get("property") == "og:image"),
        [translation],
        f"{filename} social preview",
    )

for filename, translation in (("README.md", "translation-en-es.webp"), ("README.he.md", "translation-he-en.webp")):
    page = Page(ROOT / filename)
    check(
        filenames(page, "img", "src", lambda a: Path(a["src"]).name.startswith("translation-")),
        [translation],
        f"{filename} translation screenshot",
    )

print("Verified the demo language, screenshots and social preview for each site locale and README.")
