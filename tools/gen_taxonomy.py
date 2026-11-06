#!/usr/bin/env python3
"""Build AnimalScroller/Resources/taxonomy.json from Wikidata (CC0) and English Wikipedia.

The only hand-made input is tools/species.txt, the list of English Wikipedia article titles
that decides WHICH species appear. Everything shown about them comes from open sources, so no
value is typed in by a person or an AI (decision D-011):

    common name       English Wikipedia article title (after redirects); if that title is the
                      scientific name, the English Wikidata P1843 (taxon common name) instead
    scientific name   Wikidata P225 (taxon name)
    status            Wikidata P141 (IUCN conservation status); if absent and the item is a
                      fossil taxon (P31 = Q23038290), EX; else the IUCN
                      status in the article's taxobox; otherwise NE
    tree              Wikidata P171 (parent taxon) chain, keeping kingdom, phylum, class, order
                      and family (P105 taxon rank)
    group names       English Wikipedia article title of each taxon, else its P225

It also writes tools/taxonomy-sources.json, which records the Wikidata item behind every value.

Usage:
    python3 tools/gen_taxonomy.py                # writes the two files above
    python3 tools/gen_taxonomy.py --check        # exits 1 if taxonomy.json is out of date
    python3 tools/gen_taxonomy.py --lint         # offline: species.txt, taxonomy.json and
                                                 # taxonomy-sources.json agree (runs in CI)

Every listed title must be a single species (Wikidata P105 = species or subspecies), never a genus or wider
group (AGENTS.md rule 1). Titles whose article has no free lead image or is shorter than
MIN_ARTICLE_LENGTH are reported as warnings: they make thin feed sets.

Responses are cached in tools/.cache/ (git-ignored) so re-runs don't hit the APIs again.
Delete that folder to refresh from live data.
"""
import hashlib
import json
import os
import re
import sys
import time
import urllib.parse
import urllib.request
import urllib.error

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SPECIES_LIST = os.path.join(ROOT, "tools", "species.txt")
OUT_TAXONOMY = os.path.join(ROOT, "AnimalScroller", "Resources", "taxonomy.json")
OUT_SOURCES = os.path.join(ROOT, "tools", "taxonomy-sources.json")
CACHE = os.path.join(ROOT, "tools", ".cache")

USER_AGENT = "AnimalScrollerTaxonomyBuilder/0.2 (https://github.com/Cromaximum/Axolotl)"
WIKIDATA_API = "https://www.wikidata.org/w/api.php"
ENWIKI_API = "https://en.wikipedia.org/w/api.php"

# Wikidata items this script relies on. Their English labels are checked against Wikidata at
# run time, so a wrong id stops the build instead of silently mislabelling data.
RANKS = {  # P105 value -> (rank name in taxonomy.json, expected Wikidata label)
    "Q36732": ("kingdom", "kingdom"),
    "Q38348": ("phylum", "phylum"),
    "Q37517": ("class", "class"),
    "Q36602": ("order", "order"),
    "Q35409": ("family", "family"),
}
STATUSES = {  # P141 value -> (code used by the app, expected Wikidata label)
    "Q211005": ("LC", "Least Concern"),
    "Q719675": ("NT", "Near Threatened"),
    "Q278113": ("VU", "Vulnerable"),
    "Q11394": ("EN", "endangered species"),  # older item still used on some species
    "Q96377276": ("EN", "endangered"),  # current IUCN "Endangered" item
    "Q219127": ("CR", "Critically Endangered"),
    "Q239509": ("EW", "Extinct in the Wild"),
    "Q237350": ("EX", "Extinct"),
    "Q3245245": ("DD", "Data Deficient"),
}
FOSSIL_TAXON = ("Q23038290", "fossil taxon")
SPECIES_RANK = ("Q7432", "species")
SUBSPECIES_RANK = ("Q68947", "subspecies")  # narrower than a species, still one specific animal
MIN_ARTICLE_LENGTH = 5000  # same bar as LiveCatalogRules.minArticleLength in the app
# Bar for adding a species (--screen) and for warnings on listed ones: a solid article to pull
# facts from, and enough usable photos for a full species set (intro hero, then photo, fact,
# photo, fact; FeedComposer, PR #20) without repeating one.
SCREEN_MIN_ARTICLE_LENGTH = 12000
MIN_USABLE_PHOTOS = 4
# Mirrors of the app's photo rules, so a photo counted here is one the app would show.
APP_IMAGE_LIMIT = 40      # WikiClient.images(onArticle:limit:) looks at the first 40 files
APP_THUMB_WIDTH = 1280    # ImageSizing.wikimediaThumbWidth (sizes are checked on the thumb)
ANIMALIA = ("Q729", "animal")  # P225 of this item is also checked to be "Animalia"

_last_request = 0.0


def fetch(url, params):
    """GET a MediaWiki API URL as JSON, with caching, pacing and backoff on rate limits."""
    global _last_request
    params = dict(params, format="json", formatversion="2")
    full = url + "?" + urllib.parse.urlencode(sorted(params.items()))
    key = hashlib.sha256(full.encode()).hexdigest()[:32]
    path = os.path.join(CACHE, key + ".json")
    if os.path.exists(path):
        with open(path) as f:
            return json.load(f)

    delay = 5.0
    for attempt in range(10):
        wait = 1.0 - (time.time() - _last_request)
        if wait > 0:
            time.sleep(wait)
        _last_request = time.time()
        req = urllib.request.Request(full, headers={"User-Agent": USER_AGENT, "Accept": "application/json"})
        try:
            with urllib.request.urlopen(req, timeout=60) as resp:
                body = resp.read().decode()
            data = json.loads(body)
            if "error" in data:
                raise RuntimeError(f"API error for {full}: {data['error']}")
            os.makedirs(CACHE, exist_ok=True)
            with open(path, "w") as f:
                json.dump(data, f)
            return data
        except (urllib.error.HTTPError, json.JSONDecodeError, urllib.error.URLError) as e:
            code = getattr(e, "code", None)
            retry_after = getattr(e, "headers", {}) and e.headers.get("Retry-After")
            sleep_for = float(retry_after) if retry_after and retry_after.isdigit() else delay
            print(f"  request failed ({code or e}); retrying in {sleep_for:.0f}s", file=sys.stderr)
            time.sleep(sleep_for)
            delay = min(delay * 2, 300)
    raise RuntimeError(f"Giving up on {full}")


def chunks(items, n):
    for i in range(0, len(items), n):
        yield items[i:i + n]


def best_values(entity, prop):
    """Item/string values of a claim, preferred-rank statements first, deprecated ones dropped."""
    claims = entity.get("claims", {}).get(prop, [])
    preferred = [c for c in claims if c.get("rank") == "preferred"]
    normal = [c for c in claims if c.get("rank") == "normal"]
    out = []
    for c in preferred or normal:
        snak = c.get("mainsnak", {})
        if snak.get("snaktype") != "value":
            continue
        v = snak["datavalue"]["value"]
        out.append(v["id"] if isinstance(v, dict) and "id" in v else v)
    return out


def get_entities(qids, props="claims|sitelinks|labels"):
    out = {}
    for batch in chunks(sorted(set(qids)), 25):
        data = fetch(WIKIDATA_API, {
            "action": "wbgetentities", "ids": "|".join(batch), "props": props,
            "languages": "en", "sitefilter": "enwiki",
        })
        for qid, ent in data.get("entities", {}).items():
            if "missing" not in ent:
                out[qid] = ent
    return out


def verify_reference_items():
    expected = {q: label for q, (_, label) in RANKS.items()}
    expected.update({q: label for q, (_, label) in STATUSES.items()})
    expected[FOSSIL_TAXON[0]] = FOSSIL_TAXON[1]
    expected[SPECIES_RANK[0]] = SPECIES_RANK[1]
    expected[SUBSPECIES_RANK[0]] = SUBSPECIES_RANK[1]
    expected[ANIMALIA[0]] = ANIMALIA[1]
    ents = get_entities(list(expected), props="labels")
    bad = []
    for qid, label in expected.items():
        got = ents.get(qid, {}).get("labels", {}).get("en", {}).get("value", "")
        if got.lower() != label.lower():
            bad.append(f"{qid}: expected '{label}', Wikidata says '{got}'")
    animalia = get_entities([ANIMALIA[0]], props="claims")
    if best_values(animalia.get(ANIMALIA[0], {}), "P225") != ["Animalia"]:
        bad.append(f"{ANIMALIA[0]}: P225 is not 'Animalia'")
    if bad:
        sys.exit("Reference items don't match Wikidata, fix the ids in this script:\n  " + "\n  ".join(bad))


def resolve_titles(titles, info=None):
    """English Wikipedia title -> (canonical title, Wikidata QID). If `info` is a dict, it is
    filled with canonical title -> {"length": bytes, "freeImage": file or None}."""
    out = {}
    for batch in chunks(titles, 50):
        data = fetch(ENWIKI_API, {
            "action": "query", "titles": "|".join(batch), "redirects": "1",
            "prop": "pageprops|info", "ppprop": "wikibase_item|page_image_free",
        })
        q = data["query"]
        mapping = {t: t for t in batch}
        for n in q.get("normalized", []):
            mapping = {k: (n["to"] if v == n["from"] else v) for k, v in mapping.items()}
        for r in q.get("redirects", []):
            mapping = {k: (r["to"] if v == r["from"] else v) for k, v in mapping.items()}
        pages = {p["title"]: p for p in q.get("pages", [])}
        for original, final in mapping.items():
            page = pages.get(final, {})
            qid = page.get("pageprops", {}).get("wikibase_item")
            if qid:
                out[original] = (final, qid)
                if info is not None:
                    info[final] = {"length": page.get("length", 0),
                                   "freeImage": page.get("pageprops", {}).get("page_image_free")}
    return out


def english_common_name(entity):
    """First English value of Wikidata P1843 (taxon common name), with its first letter capitalised."""
    for c in entity.get("claims", {}).get("P1843", []):
        if c.get("rank") == "deprecated" or c.get("mainsnak", {}).get("snaktype") != "value":
            continue
        v = c["mainsnak"]["datavalue"]["value"]
        if v.get("language") in ("en", "en-gb", "en-us", "en-ca") and v.get("text"):
            t = v["text"].strip()
            return t[0].upper() + t[1:]
    return None


IUCN_CODES = {"LC", "NT", "VU", "EN", "CR", "EW", "EX", "DD"}


def infobox_status(title):
    """IUCN status from the species' English Wikipedia taxobox (status + status_system = IUCN)."""
    data = fetch(ENWIKI_API, {"action": "query", "prop": "revisions", "titles": title,
                              "rvprop": "content", "rvslots": "main", "redirects": "1"})
    pages = data["query"].get("pages", [])
    if not pages or "revisions" not in pages[0]:
        return None
    text = pages[0]["revisions"][0]["slots"]["main"]["content"]
    status = re.search(r"\|\s*status\s*=\s*([A-Z]{2})\b", text)
    system = re.search(r"\|\s*status_system\s*=\s*([^\n|]+)", text)
    if status and system and "iucn" in system.group(1).lower() and status.group(1) in IUCN_CODES:
        return status.group(1)
    return None


def enwiki_title(entity):
    return entity.get("sitelinks", {}).get("enwiki", {}).get("title")


def strip_disambiguation(title):
    return re.sub(r"\s*\([^)]*\)$", "", title)


def read_species_list():
    titles = []
    with open(SPECIES_LIST) as f:
        for line in f:
            line = line.strip()
            if line and not line.startswith("#"):
                titles.append(line)
    return titles


# ---- Photo check: a Python port of ContentPolicy.licensedImages (keep the two in step) ----

ALLOWED_MIMES = {"image/jpeg", "image/png", "image/webp"}
JUNK_WORDS = [
    "map", "range", "distribution", "status_iucn", "status iucn", "logo", "icon", "flag",
    "stamp", "coin", "banknote", "symbol", "chart", "graph", "phylogen", "cladogram",
    "skull_comparison", "size_comparison", "size comparison", "scale", "commons-logo",
    "wikispecies", "wiktionary", "red_pencil", "question_book", "ambox",
]
MIN_IMAGE_WIDTH, MIN_SHORT_SIDE, MAX_ASPECT = 640, 400, 2.6


def allowed_license(short):
    """ContentPolicy.isAllowedLicense: PD, CC0, CC BY, CC BY-SA; never NC, ND or fair use."""
    name = (short or "").strip().lower()
    if not name:
        return False
    if "-nc" in name or " nc" in name or "noncommercial" in name:
        return False
    if "-nd" in name or " nd" in name or "noderiv" in name:
        return False
    if "fair use" in name or "non-free" in name:
        return False
    if name == "cc0" or name.startswith("cc0 ") or "cc zero" in name:
        return True
    if name.startswith("public domain") or name == "pd" or name.startswith(("pd-", "pd ")):
        return True
    return name.startswith(("cc by", "cc-by"))


def sharp_enough(width, height):
    """ContentPolicy.isSharpEnough, on the size of the thumb the app downloads."""
    if not width:
        return True
    if width > APP_THUMB_WIDTH and height:
        width, height = APP_THUMB_WIDTH, round(height * APP_THUMB_WIDTH / width)
    if width < MIN_IMAGE_WIDTH:
        return False
    if not height:
        return True
    if min(width, height) < MIN_SHORT_SIDE:
        return False
    return 1 / MAX_ASPECT <= width / height <= MAX_ASPECT


def usable_photo(info):
    t = info["title"].lower()
    return (info.get("mime") in ALLOWED_MIMES and not any(w in t for w in JUNK_WORDS)
            and allowed_license(info.get("license")) and sharp_enough(info.get("width"), info.get("height")))


def article_files(titles):
    """Canonical article title -> its first APP_IMAGE_LIMIT file titles, sorted like the app's
    generator=images query."""
    out = {t: [] for t in titles}
    for batch in chunks(titles, 50):
        cont = {}
        while True:
            data = fetch(ENWIKI_API, dict({"action": "query", "titles": "|".join(batch),
                                           "prop": "images", "imlimit": "max"}, **cont))
            for page in data.get("query", {}).get("pages", []):
                out.setdefault(page["title"], []).extend(i["title"] for i in page.get("images", []))
            if "continue" not in data:
                break
            cont = {k: v for k, v in data["continue"].items()}
    return {t: sorted(set(v))[:APP_IMAGE_LIMIT] for t, v in out.items()}


def file_infos(files):
    """File title -> {title, mime, width, height, license} from Commons/enwiki imageinfo."""
    out = {}
    for batch in chunks(sorted(set(files)), 50):
        data = fetch(ENWIKI_API, {"action": "query", "titles": "|".join(batch), "prop": "imageinfo",
                                  "iiprop": "mime|size|extmetadata",
                                  "iiextmetadatafilter": "LicenseShortName"})
        q = data.get("query", {})
        back = {n["to"]: n["from"] for n in q.get("normalized", [])}
        for page in q.get("pages", []):
            ii = (page.get("imageinfo") or [{}])[0]
            lic = ii.get("extmetadata", {}).get("LicenseShortName", {}).get("value")
            info = {"title": page["title"], "mime": ii.get("mime"), "width": ii.get("width"),
                    "height": ii.get("height"), "license": lic if isinstance(lic, str) else None}
            out[page["title"]] = info
            out[back.get(page["title"], page["title"])] = info
    return out


def usable_photo_counts(titles):
    """Canonical article title -> number of photos the app would accept from it."""
    files = article_files(titles)
    infos = file_infos([f for fs in files.values() for f in fs])
    return {t: sum(1 for f in fs if f in infos and usable_photo(infos[f])) for t, fs in files.items()}


def screen(path):
    """Report which candidate titles meet the bar for species.txt. Prints passing titles to
    stdout (ready to paste) and the reason for each rejection to stderr. Never edits files."""
    with open(path) as f:
        cands = [l.strip() for l in f if l.strip() and not l.startswith("#")]
    listed = read_species_list()
    page_info = {}
    have = resolve_titles(listed, {})
    have_articles = {final for final, _ in have.values()}
    resolved = resolve_titles(cands, page_info)
    entities = get_entities([q for _, q in resolved.values()])
    finals = sorted({resolved[c][0] for c in cands if c in resolved})
    photos = usable_photo_counts(finals)
    seen = set()
    for c in cands:
        if c not in resolved:
            print(f"reject {c}: no article / Wikidata item", file=sys.stderr); continue
        final, qid = resolved[c]
        ent = entities.get(qid, {})
        info = page_info.get(final, {})
        why = None
        if final in have_articles:
            why = "already listed"
        elif final in seen:
            why = "duplicate candidate"
        elif not {SPECIES_RANK[0], SUBSPECIES_RANK[0]} & set(best_values(ent, "P105")):
            why = "not a single species on Wikidata"
        elif not best_values(ent, "P225"):
            why = "no P225 scientific name"
        elif not info.get("freeImage"):
            why = "no free lead image"
        elif info.get("length", 0) < SCREEN_MIN_ARTICLE_LENGTH:
            why = f"article too short ({info.get('length', 0)} bytes)"
        elif photos.get(final, 0) < MIN_USABLE_PHOTOS:
            why = f"only {photos.get(final, 0)} usable photos"
        if why:
            print(f"reject {c} -> {final}: {why}", file=sys.stderr)
            continue
        seen.add(final)
        print(f"{c}\t{final}\t{info.get('length')}\t{photos[final]}")


def lint():
    """Offline consistency check for CI: no network, no cache needed."""
    titles = read_species_list()
    errors = []
    dupes = sorted({t for t in titles if titles.count(t) > 1})
    if dupes:
        errors.append("duplicate lines in species.txt: " + ", ".join(dupes))
    with open(OUT_SOURCES) as f:
        sources = json.load(f)
    with open(OUT_TAXONOMY) as f:
        root = json.load(f)
    listed = {v["listedAs"] for v in sources["species"].values()}
    for t in sorted(set(titles) - listed):
        errors.append(f"'{t}' is in species.txt but not generated: run tools/gen_taxonomy.py")
    for t in sorted(listed - set(titles)):
        errors.append(f"'{t}' was generated but is no longer in species.txt: run tools/gen_taxonomy.py")

    seen = []

    def walk(node):
        for sp in node.get("species", []):
            seen.append(sp["wikiTitle"])
        for child in node.get("children", []):
            walk(child)
    walk(root)
    dup_species = sorted({t for t in seen if seen.count(t) > 1})
    if dup_species:
        errors.append("species listed twice in taxonomy.json (two titles redirect to one article?): "
                      + ", ".join(dup_species))
    if set(seen) != set(sources["species"]):
        errors.append("taxonomy.json and taxonomy-sources.json list different species: "
                      "regenerate both with tools/gen_taxonomy.py, never edit them by hand")
    if errors:
        sys.exit("Species data lint failed:\n  " + "\n  ".join(errors))
    print(f"Species data lint passed: {len(seen)} species.")


def main():
    if "--lint" in sys.argv:
        lint()
        return
    if "--screen" in sys.argv:
        screen(sys.argv[sys.argv.index("--screen") + 1])
        return
    check = "--check" in sys.argv
    titles = read_species_list()

    verify_reference_items()

    page_info = {}
    resolved = resolve_titles(titles, page_info)
    missing = [t for t in titles if t not in resolved]
    if missing:
        sys.exit("No Wikipedia article / Wikidata item for: " + ", ".join(missing))
    by_article = {}
    for original, (final, _) in resolved.items():
        by_article.setdefault(final, []).append(original)
    same = [" / ".join(v) + f" -> {k}" for k, v in by_article.items() if len(v) > 1]
    if same:
        sys.exit("These lines lead to the same article:\n  " + "\n  ".join(same))

    entities = get_entities([q for _, q in resolved.values()])

    not_species = [f"{t} ({resolved[t][1]})" for t in titles
                   if not {SPECIES_RANK[0], SUBSPECIES_RANK[0]} & set(best_values(entities[resolved[t][1]], "P105"))]
    if not_species:
        sys.exit("Not a single species on Wikidata (P105 is not species or subspecies), so it would show a group "
                 "(AGENTS.md rule 1). Use a species article or drop it:\n  " + "\n  ".join(not_species))
    for t in titles:
        page = page_info.get(resolved[t][0], {})
        if not page.get("freeImage"):
            print(f"  warning: {t}: article has no free lead image", file=sys.stderr)
        if page.get("length", 0) < MIN_ARTICLE_LENGTH:
            print(f"  warning: {t}: article is short ({page.get('length', 0)} bytes)", file=sys.stderr)

    # Walk P171 (parent taxon) up from every species until each chain reaches a kingdom.
    parent_of = {}
    frontier = set(entities)
    for _ in range(80):
        need = set()
        for qid in frontier:
            ent = entities[qid]
            ranks = best_values(ent, "P105")
            parents = best_values(ent, "P171")
            if qid != ANIMALIA[0] and "Q36732" not in ranks and parents:
                parent_of[qid] = parents[0]
                if parents[0] not in entities:
                    need.add(parents[0])
        if not need:
            break
        entities.update(get_entities(list(need)))
        frontier = need & set(entities)

    def lineage(qid):
        chain, seen = [], set()
        while qid in parent_of and qid not in seen:
            seen.add(qid)
            qid = parent_of[qid]
            chain.append(qid)
        return list(reversed(chain))  # root first

    used_ids = set()

    def slug(text):
        s = re.sub(r"[^a-z0-9]+", "-", text.lower()).strip("-")
        base, i = s, 2
        while s in used_ids:
            s, i = f"{base}-{i}", i + 1
        used_ids.add(s)
        return s

    nodes = {}  # qid -> taxon dict
    sources = {"generatedFrom": "Wikidata (CC0) and English Wikipedia", "taxa": {}, "species": {}}
    root = None
    problems = []

    def node_for(qid):
        nonlocal root
        if qid in nodes:
            return nodes[qid]
        ent = entities[qid]
        rank = RANKS[next(r for r in best_values(ent, "P105") if r in RANKS)][0]
        sci = (best_values(ent, "P225") or [ent.get("labels", {}).get("en", {}).get("value", qid)])[0]
        title = enwiki_title(ent)
        name = strip_disambiguation(title) if title else sci
        node = {"id": slug(sci), "name": name, "scientificName": sci, "rank": rank}
        nodes[qid] = node
        sources["taxa"][node["id"]] = {"qid": qid, "name": "enwiki title" if title else "P225",
                                       "scientificName": "P225", "rank": "P105"}
        return node

    for original in titles:
        final_title, qid = resolved[original]
        ent = entities[qid]
        kept = [q for q in lineage(qid)
                if q in entities and any(r in RANKS for r in best_values(entities[q], "P105"))]
        if not kept or kept[0] != ANIMALIA[0]:
            problems.append(f"{original}: tree from Wikidata doesn't reach Animalia")
            continue
        parent = None
        for q in kept:
            node = node_for(q)
            if parent is None:
                root = root or node
            else:
                kids = parent.setdefault("children", [])
                if node not in kids:
                    kids.append(node)
            parent = node

        sci = best_values(ent, "P225")
        if not sci:
            problems.append(f"{original}: no P225 scientific name on {qid}")
            continue
        status_q = [s for s in best_values(ent, "P141") if s in STATUSES]
        if status_q:
            status, status_src = STATUSES[status_q[0]][0], f"P141 {status_q[0]}"
        elif FOSSIL_TAXON[0] in best_values(ent, "P31"):
            status, status_src = "EX", f"P31 {FOSSIL_TAXON[0]} (fossil taxon)"
        elif infobox_status(final_title):
            status, status_src = infobox_status(final_title), "enwiki taxobox status (IUCN)"
        else:
            status, status_src = "NE", "no P141 on Wikidata, no IUCN status in taxobox"
        # Common name: the article title, unless that is just the scientific name and Wikidata
        # has an English common name (P1843).
        common, common_src = final_title, "enwiki title"
        if final_title.lower() in {n.lower() for n in sci}:
            p1843 = english_common_name(ent)
            if p1843:
                common, common_src = p1843, "P1843 (en)"
        parent.setdefault("species", []).append({
            "wikiTitle": final_title,
            "commonName": common,
            "scientificName": sci[0],
            "status": status,
        })
        sources["species"][final_title] = {"qid": qid, "commonName": common_src,
                                           "scientificName": "P225", "status": status_src,
                                           "listedAs": original}

    if problems:
        sys.exit("Problems:\n  " + "\n  ".join(problems))

    text = json.dumps(root, indent=2, ensure_ascii=False) + "\n"
    if check:
        with open(OUT_TAXONOMY) as f:
            if f.read() != text:
                sys.exit("taxonomy.json is out of date or was edited by hand. Run tools/gen_taxonomy.py.")
        print("taxonomy.json matches the sources.")
        return

    with open(OUT_TAXONOMY, "w") as f:
        f.write(text)
    with open(OUT_SOURCES, "w") as f:
        json.dump(sources, f, indent=2, ensure_ascii=False)
        f.write("\n")
    n = len(sources["species"])
    ex = sum(1 for s in sources["species"].values() if s["status"].startswith(("P141 Q237350", "P31")))
    print(f"{n} species ({ex} extinct), {len(nodes)} taxa")


if __name__ == "__main__":
    main()
