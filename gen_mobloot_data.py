#!/usr/bin/env python3
"""
Generate the data files for the MobLoot addon - NO database and NO pip needed.

Downloads the AzerothCore (WotLK 3.3.5a) world-database SQL files from GitHub,
reads them directly and writes:
    MobLootData.lua   creature drop tables
    MobLootInfo.lua   names, levels, locations, vendors, quests, chests/nodes, containers,
                      crafting recipes (from the client's Spell.dbc / SkillLineAbility.dbc)
                      and trainers

    python gen_mobloot_data.py

The two .lua files are written next to this script (use --out-dir to choose another folder).

Options:
  --sql-dir DIR    use already-downloaded .sql files from DIR instead of downloading
  --dbc-dir DIR    use Spell.dbc and SkillLineAbility.dbc from DIR instead of downloading
                   them (optional; by default they are fetched from the AzerothCore
                   client-data release, only these two files, a few MB).
  --out-dir DIR    where to write the .lua files (default: the folder of this script)
  --min-quality N  0=grey 1=white 2=green 3=blue 4=epic   (default 1: hides grey junk)
  --min-chance P   drop entries below P percent           (default 0.1)
  --keep-cache     keep the downloaded files (mobloot_cache) after generating;
                   by default they are deleted once the addon data is written.
"""
import argparse, collections, os, re, shutil, struct, sys, urllib.request, zlib

BASE = ("https://raw.githubusercontent.com/azerothcore/azerothcore-wotlk/"
        "master/data/sql/base/db_world/{}.sql")
TABLES = ["creature_loot_template", "reference_loot_template", "gameobject_loot_template",
          "item_loot_template", "creature_template", "item_template", "creature",
          "gameobject", "gameobject_template", "npc_vendor", "quest_template",
          "game_graveyard", "creature_queststarter", "creature_questender",
          "trainer_spell", "creature_default_trainer", "npc_trainer"]

CLIENT_DATA_URL = "https://github.com/wowgaming/client-data/releases/latest/download/data.zip"
DBC_NAMES = ("Spell.dbc", "SkillLineAbility.dbc")

PROFS = {171: "A",   # Alchemy
         164: "B",   # Blacksmithing
         333: "D",   # Enchanting
         202: "E",   # Engineering
         773: "I",   # Inscription
         755: "J",   # Jewelcrafting
         165: "L",   # Leatherworking
         197: "T",   # Tailoring
         185: "W",   # Cooking
         129: "X",   # First Aid
         186: "Y"}   # Mining

# DBC layout of 3.3.5a build 12340
SPELL_FIELDS, SLA_FIELDS = 234, 14
SP_NAME = 136            # Name_lang, enUS slot (offset into the string block)
SP_REAGENT = 52          # Reagent[8]
SP_REAGENT_COUNT = 60    # ReagentCount[8]
SP_EFFECT = 71           # Effect[3]
SP_BASEPOINTS = 80       # EffectBasePoints[3]
SP_ITEMTYPE = 107        # EffectItemType[3]
SLA_SKILL, SLA_SPELL, SLA_MINRANK = 1, 2, 7
EFFECT_ENCHANT_ITEM, EFFECT_CREATE_ITEM, EFFECT_CREATE_ITEM_2 = 53, 24, 157
JUNK_SPELL = re.compile(r"^(zz|old\b|\(old\)|deprecated|\[deprecated|test\b|dnt\b)", re.I)
RECIPE_ROW = re.compile(r"\(\d+,9,")

OUTDOOR = {0: "Eastern Kingdoms", 1: "Kalimdor", 530: "Outland", 571: "Northrend"}
ZONE_CONT = {"Eversong Woods": "Eastern Kingdoms", "Ghostlands": "Eastern Kingdoms",
             "Silvermoon City": "Eastern Kingdoms", "Azuremyst Isle": "Kalimdor",
             "Bloodmyst Isle": "Kalimdor", "The Exodar": "Kalimdor"}
MAPS = {
    30: "Alterac Valley", 33: "Shadowfang Keep", 34: "The Stockade", 36: "The Deadmines",
    43: "Wailing Caverns", 47: "Razorfen Kraul", 48: "Blackfathom Deeps", 70: "Uldaman",
    90: "Gnomeregan", 109: "The Temple of Atal'Hakkar", 129: "Razorfen Downs",
    189: "Scarlet Monastery", 209: "Zul'Farrak", 229: "Blackrock Spire", 230: "Blackrock Depths",
    249: "Onyxia's Lair", 269: "The Black Morass", 289: "Scholomance", 309: "Zul'Gurub",
    329: "Stratholme", 349: "Maraudon", 389: "Ragefire Chasm", 409: "Molten Core",
    429: "Dire Maul", 469: "Blackwing Lair", 489: "Warsong Gulch", 509: "Ruins of Ahn'Qiraj",
    529: "Arathi Basin", 531: "Ahn'Qiraj Temple", 532: "Karazhan", 533: "Naxxramas",
    534: "Hyjal Summit", 540: "The Shattered Halls", 542: "The Blood Furnace",
    543: "Hellfire Ramparts", 544: "Magtheridon's Lair", 545: "The Steamvault",
    546: "The Underbog", 547: "The Slave Pens", 548: "Serpentshrine Cavern",
    550: "Tempest Keep", 552: "The Arcatraz", 553: "The Botanica", 554: "The Mechanar",
    555: "Shadow Labyrinth", 556: "Sethekk Halls", 557: "Mana-Tombs", 558: "Auchenai Crypts",
    560: "Old Hillsbrad Foothills", 564: "Black Temple", 565: "Gruul's Lair", 566: "Eye of the Storm",
    568: "Zul'Aman", 574: "Utgarde Keep", 575: "Utgarde Pinnacle", 576: "The Nexus",
    578: "The Oculus", 580: "Sunwell Plateau", 585: "Magisters' Terrace",
    595: "The Culling of Stratholme", 599: "Halls of Stone", 600: "Drak'Tharon Keep",
    601: "Azjol-Nerub", 602: "Halls of Lightning", 603: "Ulduar", 604: "Gundrak",
    607: "Strand of the Ancients", 608: "The Violet Hold", 615: "The Obsidian Sanctum",
    616: "The Eye of Eternity", 619: "Ahn'kahet: The Old Kingdom", 624: "Vault of Archavon",
    628: "Isle of Conquest", 631: "Icecrown Citadel", 632: "The Forge of Souls",
    649: "Trial of the Crusader", 650: "Trial of the Champion", 658: "Pit of Saron",
    668: "Halls of Reflection", 724: "The Ruby Sanctum",
}

ZONES = {
    1: "Dun Morogh", 3: "Badlands", 4: "Blasted Lands", 8: "Swamp of Sorrows", 10: "Duskwood",
    11: "Wetlands", 12: "Elwynn Forest", 14: "Durotar", 15: "Dustwallow Marsh", 16: "Azshara",
    17: "The Barrens", 28: "Western Plaguelands", 33: "Stranglethorn Vale", 36: "Alterac Mountains",
    38: "Loch Modan", 40: "Westfall", 41: "Deadwind Pass", 44: "Redridge Mountains",
    45: "Arathi Highlands", 46: "Burning Steppes", 47: "The Hinterlands", 51: "Searing Gorge",
    85: "Tirisfal Glades", 130: "Silverpine Forest", 139: "Eastern Plaguelands", 141: "Teldrassil",
    148: "Darkshore", 215: "Mulgore", 267: "Hillsbrad Foothills", 331: "Ashenvale",
    357: "Feralas", 361: "Felwood", 400: "Thousand Needles", 405: "Desolace",
    406: "Stonetalon Mountains", 440: "Tanaris", 490: "Un'Goro Crater", 493: "Moonglade",
    618: "Winterspring", 1377: "Silithus", 3430: "Eversong Woods", 3433: "Ghostlands",
    3524: "Azuremyst Isle", 3525: "Bloodmyst Isle", 3483: "Hellfire Peninsula", 3518: "Nagrand",
    3519: "Terokkar Forest", 3520: "Shadowmoon Valley", 3521: "Zangarmarsh",
    3522: "Blade's Edge Mountains", 3523: "Netherstorm", 3537: "Borean Tundra",
    495: "Howling Fjord", 394: "Grizzly Hills", 65: "Dragonblight", 66: "Zul'Drak",
    67: "The Storm Peaks", 210: "Icecrown", 3711: "Sholazar Basin", 2817: "Crystalsong Forest",
    4197: "Wintergrasp", 4298: "Plaguelands: The Scarlet Enclave", 4742: "Hrothgar's Landing",
    1519: "Stormwind City", 1537: "Ironforge", 1637: "Orgrimmar", 1638: "Thunder Bluff",
    1657: "Darnassus", 1497: "Undercity", 3487: "Silvermoon City", 3557: "The Exodar",
    9: "Elwynn Forest", 132: "Dun Morogh", 154: "Tirisfal Glades", 188: "Teldrassil",
    220: "Mulgore", 363: "Durotar", 3431: "Eversong Woods", 3526: "Azuremyst Isle",
    3703: "Shattrath City", 4395: "Dalaran", 2597: "Alterac Valley", 3456: "Naxxramas",
}

def get_file(name, sql_dir, cache):
    if sql_dir:
        return os.path.join(sql_dir, name + ".sql")
    os.makedirs(cache, exist_ok=True)
    path = os.path.join(cache, name + ".sql")
    if not os.path.exists(path):
        print(f"Downloading {name}.sql ...")
        try:
            urllib.request.urlretrieve(BASE.format(name), path)
        except Exception as e:
            sys.exit(f"Download failed for {name}: {e}")
    return path


def find_dbc_dir(a, cache):
    def ok(d):
        return d and all(os.path.exists(os.path.join(d, n)) for n in DBC_NAMES)
    if a.dbc_dir:
        if not ok(a.dbc_dir):
            sys.exit(f"{a.dbc_dir} must contain {' and '.join(DBC_NAMES)}")
        return a.dbc_dir
    d = os.path.join(cache, "dbc")
    if not ok(d):
        print("Downloading Spell.dbc / SkillLineAbility.dbc from the AzerothCore client data ...")
        try:
            fetch_dbcs_from_zip(CLIENT_DATA_URL, d)
        except Exception as e:
            sys.exit(f"Could not download the DBC files: {e}\n"
                     f"Pass --dbc-dir with a folder that contains them instead.")
    return d


def _get(url, rng):
    req = urllib.request.Request(url, headers={"Range": "bytes=" + rng, "User-Agent": "gen_mobloot_data"})
    with urllib.request.urlopen(req, timeout=120) as r:
        return r.read(), r.headers.get("Content-Range", "")


def _zip64_extra(extra, usize, csize, lho):
    i = 0
    while i + 4 <= len(extra):
        tag, ln = struct.unpack_from("<HH", extra, i)
        if tag == 1:
            p = i + 4
            vals = []
            for cur in (usize, csize, lho):
                if cur == 0xFFFFFFFF:
                    cur = struct.unpack_from("<Q", extra, p)[0]; p += 8
                vals.append(cur)
            return vals
        i += 4 + ln
    return [usize, csize, lho]


def fetch_dbcs_from_zip(url, dest):
    _, cr = _get(url, "0-0")                           # Content-Range tells the total size
    total = int(cr.rsplit("/", 1)[1])
    tail, _ = _get(url, f"{max(total - 131072, 0)}-{total - 1}")   # central directory locator
    i = tail.rfind(b"PK\x05\x06")
    if i < 0:
        sys.exit("client-data zip: end of central directory not found")
    cd_size, cd_off = struct.unpack_from("<II", tail, i + 12)
    if cd_off == 0xFFFFFFFF or cd_size == 0xFFFFFFFF:  # zip64
        j = tail.rfind(b"PK\x06\x07", 0, i)
        z64_off = struct.unpack_from("<Q", tail, j + 8)[0]
        rec, _ = _get(url, f"{z64_off}-{z64_off + 55}")
        cd_size, cd_off = struct.unpack_from("<QQ", rec, 40)
    cd, _ = _get(url, f"{cd_off}-{cd_off + cd_size - 1}")
    found, p = {}, 0
    while p + 46 <= len(cd) and cd[p:p + 4] == b"PK\x01\x02":
        (_, _, _, flags, method, _, _, _, csize, usize, nl, el, cl, _, _, _, lho) = \
            struct.unpack_from("<4s6H3I5H2I", cd, p)
        name = cd[p + 46:p + 46 + nl].decode("utf-8", "replace").replace("\\", "/")
        extra = cd[p + 46 + nl:p + 46 + nl + el]
        parts = name.lower().split("/")
        for want in DBC_NAMES:
            if parts[-1] == want.lower() and len(parts) >= 2 and parts[-2] == "dbc" and want not in found:
                usize, csize, lho = _zip64_extra(extra, usize, csize, lho)
                found[want] = (method, csize, lho)
        p += 46 + nl + el + cl
    missing = [n for n in DBC_NAMES if n not in found]
    if missing:
        sys.exit("client-data zip does not contain " + ", ".join(missing))
    os.makedirs(dest, exist_ok=True)
    for name, (method, csize, lho) in found.items():
        lh, _ = _get(url, f"{lho}-{lho + 29}")
        nl, el = struct.unpack_from("<HH", lh, 26)
        start = lho + 30 + nl + el
        raw, _ = _get(url, f"{start}-{start + csize - 1}")
        data = zlib.decompress(raw, -15) if method == 8 else raw
        with open(os.path.join(dest, name), "wb") as fh:
            fh.write(data)
        print(f"  extracted {name} ({len(data) / 1e6:.1f} MB)")


def read_dbc(path, fields):
    with open(path, "rb") as fh:
        data = fh.read()
    magic, n, nf, rs, ssz = struct.unpack_from("<4s4I", data, 0)
    if magic != b"WDBC" or rs != nf * 4:
        sys.exit(f"{path}: not a usable WDBC file")
    if nf != fields:
        sys.exit(f"{path}: has {nf} fields, expected {fields}. These must be the 3.3.5a "
                 f"(build 12340) DBCs.")
    end = 20 + n * rs
    recs = list(struct.Struct(f"<{nf}i").iter_unpack(memoryview(data)[20:end]))
    return recs, data[end:end + ssz]


def dbc_string(block, off):
    if off <= 0 or off >= len(block):
        return ""
    return block[off:block.index(b"\0", off)].decode("utf-8", "replace")


def table_columns(path):
    cols, on = [], False
    with open(path, encoding="utf-8", errors="replace") as fh:
        for line in fh:
            if line.startswith("CREATE TABLE"):
                on = True
                continue
            if on:
                m = re.match(r"\s*`(\w+)`", line)
                if m:
                    cols.append(m.group(1))
                elif line.lstrip().startswith(("PRIMARY", "KEY", "UNIQUE", "CONSTRAINT", ")")):
                    break
    return cols


def load_recipe_items(path):
    ci = {c: i for i, c in enumerate(table_columns(path))}
    try:
        slots = [(ci[f"spellid_{k}"], ci[f"spelltrigger_{k}"]) for k in range(1, 6)]
    except KeyError as e:
        sys.exit(f"item_template has no column {e}; its layout changed.")
    out = {}
    for line in lines(path):
        if not RECIPE_ROW.match(line):
            continue
        r = split_row(line)
        for s, t in slots:
            if int(r[t]) == 6 and int(r[s]) > 0:      # trigger 6 = learn spell
                out.setdefault(int(r[s]), int(r[0]))
    return out


def load_recipes(dbc_dir, iname, recipe_items):
    sla, _ = read_dbc(os.path.join(dbc_dir, "SkillLineAbility.dbc"), SLA_FIELDS)
    ability = {}                                       # spell -> (letter, min skill)
    for r in sla:
        if r[SLA_SKILL] in PROFS:
            ability.setdefault(r[SLA_SPELL], (PROFS[r[SLA_SKILL]], max(r[SLA_MINRANK], 0)))
    spells, strings = read_dbc(os.path.join(dbc_dir, "Spell.dbc"), SPELL_FIELDS)
    out = {}
    for r in spells:
        spell = r[0]
        if spell not in ability:
            continue
        item, yld, enchant = 0, 1, False
        for e in range(3):
            eff = r[SP_EFFECT + e]
            if eff in (EFFECT_CREATE_ITEM, EFFECT_CREATE_ITEM_2) and r[SP_ITEMTYPE + e] > 0:
                item, yld = r[SP_ITEMTYPE + e], max(r[SP_BASEPOINTS + e] + 1, 1)
                break
            if eff == EFFECT_ENCHANT_ITEM:
                enchant = True
        if not item and not enchant:
            continue
        if item and item not in iname:
            continue
        reagents = [(r[SP_REAGENT + i], r[SP_REAGENT_COUNT + i]) for i in range(8)
                    if r[SP_REAGENT + i] > 0 and r[SP_REAGENT_COUNT + i] > 0]
        if not reagents or any(rid not in iname for rid, _ in reagents):
            continue
        if JUNK_SPELL.match(dbc_string(strings, r[SP_NAME]).strip()):
            continue
        recipe = recipe_items.get(spell, 0)
        if recipe and recipe not in iname:
            recipe = 0
        prof, skill = ability[spell]
        out[spell] = (prof, skill, item, yld, recipe, reagents)
    return out


def load_trainers(p, ctemplate):
    by_trainer = collections.defaultdict(set)         # trainer id -> spells
    for r in fast_rows(p["trainer_spell"], 2):
        by_trainer[int(r[0])].add(int(r[1]))
    creatures_of = collections.defaultdict(set)       # trainer id -> creatures
    for r in fast_rows(p["creature_default_trainer"], 2):
        creatures_of[int(r[1])].add(int(r[0]))
    spell_creatures = collections.defaultdict(set)
    for tid, spells in by_trainer.items():
        for cid in creatures_of.get(tid, ()):
            for sp in spells:
                spell_creatures[sp].add(cid)
    #npc_trainer: positive spell = direct, negative = reference to another list
    direct, refs = collections.defaultdict(set), collections.defaultdict(set)
    for r in fast_rows(p["npc_trainer"], 2):
        eid, sp = int(r[0]), int(r[1])
        (direct if sp > 0 else refs)[eid].add(sp if sp > 0 else -sp)
    def spells_of(eid, depth=0):
        res = set(direct.get(eid, ()))
        if depth < 3:
            for ref in refs.get(eid, ()):
                res |= spells_of(ref, depth + 1)
        return res
    for eid in set(direct) | set(refs):
        if eid in ctemplate:
            for sp in spells_of(eid):
                spell_creatures[sp].add(eid)
    return spell_creatures


def split_row(line):
    line = line.rstrip()
    if line.endswith((",", ";")):
        line = line[:-1]
    line = line[1:-1]
    out, buf, in_q, i, n = [], [], False, 0, len(line)
    while i < n:
        c = line[i]
        if in_q:
            if c == "\\":
                buf.append(line[i + 1:i + 2]); i += 2; continue
            if c == "'":
                if line[i + 1:i + 2] == "'":
                    buf.append("'"); i += 2; continue
                in_q = False
            else:
                buf.append(c)
        elif c == "'":
            in_q = True
        elif c == ",":
            out.append("".join(buf)); buf = []
        else:
            buf.append(c)
        i += 1
    out.append("".join(buf))
    return out


def lines(path):
    with open(path, encoding="utf-8", errors="replace") as fh:
        for line in fh:
            if line.startswith("("):
                yield line


def rows(path, limit):
    for line in lines(path):
        yield split_row(line)[:limit]


def fast_rows(path, n):
    for line in lines(path):
        f = line.split(",", n)
        f[0] = f[0][1:]
        f = f[:n]
        f[-1] = f[-1].split(")", 1)[0]
        yield f


ITEM_RE = re.compile(r"\((\d+),\d+,\d+,-?\d+,'((?:[^'\\]|\\.|'')*)',\d+,(\d+),")


def item_rows(path):
    for line in lines(path):
        m = ITEM_RE.match(line)
        if m:
            name = m.group(2).replace("\\'", "'").replace("''", "'").replace('\\"', '"')
            yield int(m.group(1)), name, int(m.group(3))


def load_loot(path):
    d = collections.defaultdict(list)
    for r in rows(path, 9):   # Entry,Item,Reference,Chance,QuestRequired,LootMode,GroupId,Min,Max
        d[int(r[0])].append(dict(item=int(r[1]), ref=int(r[2]), chance=abs(float(r[3])),
                                 group=int(r[6]), min=max(int(r[7]), 1), max=max(int(r[8]), 1)))
    return d


def expand(rows_, refs, scale, depth, out):
    def emit(r, eff):
        p = scale * eff / 100.0
        if r["ref"]:
            if depth < 6:
                expand(refs.get(r["ref"], []), refs, p, depth + 1, out)
            return
        cur = out.get(r["item"])
        if cur:
            cur[0] = 1 - (1 - cur[0]) * (1 - p)
            cur[1] = min(cur[1], r["min"]); cur[2] = max(cur[2], r["max"])
        else:
            out[r["item"]] = [p, r["min"], r["max"]]

    groups = collections.defaultdict(list)
    for r in rows_:
        if r["group"] > 0:
            groups[r["group"]].append(r)
        else:
            emit(r, r["chance"] if r["chance"] > 0 else 100.0)
    for rs in groups.values():
        explicit = sum(r["chance"] for r in rs if r["chance"] > 0)
        zeros = [r for r in rs if r["chance"] <= 0]
        share = max(0.0, 100.0 - explicit) / len(zeros) if zeros else 0.0
        for r in rs:
            emit(r, r["chance"] if r["chance"] > 0 else share)


def resolve(table, lootid, refs, quality, a):
    base = table.get(lootid)
    if not base:
        return None
    out = {}
    expand(base, refs, 1.0, 0, out)
    items = [(i, v[0] * 100, v[1], v[2]) for i, v in out.items()
             if quality.get(i, -1) >= a.min_quality and v[0] * 100 >= a.min_chance]
    if not items:
        return None
    items.sort(key=lambda t: -t[1])
    return items


def loot_str(items):
    return ",".join(f"{i}:{c:.2f}:{mn}:{mx}" for i, c, mn, mx in items)


class Locator:
    CELL = 400.0

    def __init__(self, gy_path, zone_samples):
        self.gy = collections.defaultdict(list)
        for r in rows(gy_path, 6):          # ID, Map, x, y, z, Comment
            if len(r) >= 6 and r[5].strip():
                self.gy[int(r[1])].append((float(r[2]), float(r[3]), r[5].strip()))
        self.grid = collections.defaultdict(list)
        for m, x, y, z in zone_samples:
            self.grid[(m, int(x // self.CELL), int(y // self.CELL))].append((x, y, z))
        self.memo = {}

    def zone(self, m, x, y):
        key = (m, int(x // 60), int(y // 60))
        if key in self.memo:
            return self.memo[key]
        cx, cy = int(x // self.CELL), int(y // self.CELL)
        cand = []
        for R in (2, 6):
            for gx in range(cx - R, cx + R + 1):
                for gy in range(cy - R, cy + R + 1):
                    for sx, sy, z in self.grid.get((m, gx, gy), ()):
                        cand.append(((sx - x) ** 2 + (sy - y) ** 2, z))
            if len(cand) >= 3:
                break
        best = None
        if cand:
            cand.sort(key=lambda t: t[0])
            votes = collections.Counter()
            for d2, z in cand[:5]:
                votes[z] += 1.0 / (d2 ** 0.5 + 50.0)
            best = votes.most_common(1)[0][0]
        elif self.gy.get(m):
            g = min(self.gy[m], key=lambda g: (g[0] - x) ** 2 + (g[1] - y) ** 2)
            best = "near " + g[2]
        self.memo[key] = best
        return best

    def describe(self, spawns):
        if not spawns:
            return ""
        bymap = collections.defaultdict(list)
        for m, x, y in spawns:
            bymap[m].append((x, y))
        parts = []
        for m, pts in sorted(bymap.items(), key=lambda kv: -len(kv[1]))[:3]:
            if m in OUTDOOR:
                if len(pts) > 40:
                    step = len(pts) / 40.0
                    pts = [pts[int(i * step)] for i in range(40)]
                cnt = collections.Counter(z for z in (self.zone(m, x, y) for x, y in pts) if z)
                if not cnt:
                    parts.append(OUTDOOR[m]); continue
                tot = sum(cnt.values())
                labels = [l for l, c in cnt.most_common(3) if c / tot >= 0.2] or [cnt.most_common(1)[0][0]]
                bycont = collections.OrderedDict()
                for l in labels:
                    bycont.setdefault(ZONE_CONT.get(l, OUTDOOR[m]), []).append(l)
                for cont, zs in bycont.items():
                    parts.append(f"{', '.join(zs)} ({cont})")
            else:
                parts.append(MAPS.get(m) or f"Map {m}")
        return "; ".join(parts)


def clean(s):
    return s.replace("|", "/")


def lua_str(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"').replace("\n", " ") + '"'


def write_table(fh, var, data, chunk=2500):
    fh.write(f"{var} = {var} or {{}}\n")
    keys = sorted(data)
    for i in range(0, len(keys), chunk):
        fh.write(f";(function() local T = {var}\n")
        for k in keys[i:i + chunk]:
            fh.write(f"T[{k}]={lua_str(data[k])}\n")
        fh.write("end)()\n")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--sql-dir")
    ap.add_argument("--dbc-dir", help="folder with Spell.dbc and SkillLineAbility.dbc")
    ap.add_argument("--min-quality", type=int, default=1)
    ap.add_argument("--min-chance", type=float, default=0.1)
    ap.add_argument("--out-dir", default=os.path.dirname(os.path.abspath(__file__)))
    ap.add_argument("--keep-cache", action="store_true",
                    help="do not delete the downloaded files afterwards")
    a = ap.parse_args()

    cache = os.path.join(os.path.dirname(os.path.abspath(__file__)), "mobloot_cache")
    dbc_dir = find_dbc_dir(a, cache)   # fail early, before the big SQL downloads
    p = {t: get_file(t, a.sql_dir, cache) for t in TABLES}

    print("Reading items ...")
    quality, iname = {}, {}
    for eid, name, q in item_rows(p["item_template"]):
        quality[eid] = q; iname[eid] = name

    print("Reading crafting recipes ...")
    recipes = load_recipes(dbc_dir, iname, load_recipe_items(p["item_template"]))

    print("Reading loot tables ...")
    refs = load_loot(p["reference_loot_template"])
    cloot = load_loot(p["creature_loot_template"])
    gloot = load_loot(p["gameobject_loot_template"])
    bloot = load_loot(p["item_loot_template"])

    print("Reading creatures ...")
    ctemplate = {}      # id -> (name, minlvl, maxlvl, rank, diff1, lootid)
    for r in rows(p["creature_template"], 35):
        ctemplate[int(r[0])] = (r[6], int(r[10]), int(r[11]), int(r[20]), int(r[1]), int(r[34]))

    trainer_cand = {}
    for sp, cids in load_trainers(p, ctemplate).items():
        if sp in recipes:
            trainer_cand[sp] = sorted(c for c in cids if c in ctemplate)

    drops = {}
    for npc, t in ctemplate.items():
        if t[5] > 0:
            items = resolve(cloot, t[5], refs, quality, a)
            if items:
                drops[npc] = items

    vend = collections.defaultdict(list)
    for r in fast_rows(p["npc_vendor"], 3):          # entry, slot, item
        npc, item = int(r[0]), int(r[2])
        if npc > 0 and quality.get(item, -1) >= a.min_quality and item not in vend[npc]:
            vend[npc].append(item)
    vend = {k: v for k, v in vend.items() if v and k in ctemplate}

    print("Reading objects ...")
    objname, objloot = {}, {}
    for r in rows(p["gameobject_template"], 10):     # entry,type,display,name,...,Data0,Data1
        if int(r[1]) == 3 and int(r[9]) > 0:
            items = resolve(gloot, int(r[9]), refs, quality, a)
            if items:
                objname[int(r[0])] = r[3]; objloot[int(r[0])] = items

    baglot = {}
    for item in bloot:
        items = resolve(bloot, item, refs, quality, a)
        if items and item in iname:
            baglot[item] = items

    print("Reading quests ...")
    qinfo, qrew, qzone, qkill = {}, {}, {}, {}
    for r in rows(p["quest_template"], 83):
        if len(r) < 75:
            continue
        if int(r[4]) in ZONES:
            qzone[int(r[0])] = int(r[4])
            qkill[int(r[0])] = [int(r[i]) for i in (79, 80, 81, 82) if int(r[i]) > 0]
        rew = [int(r[i]) for i in (22, 24, 26, 28) if int(r[i]) > 0]
        rew = [i for i in rew if quality.get(i, -1) >= a.min_quality]
        ch = [-int(r[i]) for i in (38, 40, 42, 44, 46, 48) if int(r[i]) > 0]
        ch = [i for i in ch if quality.get(-i, -1) >= a.min_quality]
        if rew or ch:
            qid = int(r[0])
            qrew[qid] = ",".join(str(i) for i in rew + ch)
            qinfo[qid] = f"{r[2]}|{clean(r[74])}"

    wanted = set(drops) | set(vend)
    normal_of = {t[4]: n for n, t in ctemplate.items() if t[4] > 0}
    giver_zone = collections.defaultdict(collections.Counter)
    for tbl in ("creature_queststarter", "creature_questender"):
        for r in fast_rows(p[tbl], 2):
            z = qzone.get(int(r[1]))
            if z:
                giver_zone[int(r[0])][z] += 1
    for qid, kills in qkill.items():
        for cid in kills:
            giver_zone[cid][qzone[qid]] += 1
    need_spawn = set(wanted) | {normal_of[h] for h in wanted if h in normal_of} | set(giver_zone)
    need_spawn |= {c for cs in trainer_cand.values() for c in cs}

    print("Locating spawns ...")
    cspawn = collections.defaultdict(list)
    for r in fast_rows(p["creature"], 13):           # guid,id1,id2,id3,map,zone,area,mask,phase,equip,x,y,z
        for idx in (1, 2, 3):
            cid = int(r[idx])
            if cid in need_spawn:
                cspawn[cid].append((int(r[4]), float(r[10]), float(r[11])))
    ospawn = collections.defaultdict(list)
    for r in fast_rows(p["gameobject"], 10):         # guid,id,map,zone,area,mask,phase,x,y,z
        oid = int(r[1])
        if oid in objname:
            ospawn[oid].append((int(r[2]), float(r[7]), float(r[8])))

    samples, seen = [], set()
    for cid, cnt in giver_zone.items():
        zname = ZONES[cnt.most_common(1)[0][0]]
        for m, x, y in cspawn.get(cid, ()):
            if m in OUTDOOR:
                k = (m, int(x // 40), int(y // 40), zname)
                if k not in seen:
                    seen.add(k); samples.append((m, x, y, zname))
    print(f"  {len(samples)} zone reference points")
    loc = Locator(p["game_graveyard"], samples)
    cache_area = {}
    def area_of(cid):
        if cid not in cache_area:
            cache_area[cid] = loc.describe(cspawn.get(cid))
        return cache_area[cid]

    trainers = {}
    for sp, cids in trainer_cand.items():
        seen_ta, chosen = set(), []
        for c in cids:
            if not cspawn.get(c):
                continue
            key = (ctemplate[c][0], area_of(c))
            if key in seen_ta:
                continue
            seen_ta.add(key); chosen.append(c)
        if chosen:
            trainers[sp] = chosen[:12]
    wanted |= {c for cs in trainers.values() for c in cs}

    mobs = {}
    for cid in wanted:
        name, mn, mx, rank, diff1, _ = ctemplate[cid]
        area = area_of(cid)
        if not area and cid in normal_of:
            area = area_of(normal_of[cid])
            if ctemplate[normal_of[cid]][0] == name:
                name += " [Heroic/25]"
        mobs[cid] = f"{clean(name)}|{mn}|{mx}|{rank}|{area}"
    objs = {oid: f"{clean(objname[oid])}|{loc.describe(ospawn.get(oid))}" for oid in objname}

    used = set()
    for d in (drops, objloot, baglot):
        for items in d.values():
            used.update(i for i, *_ in items)
    for v in vend.values():
        used.update(v)
    for s in qrew.values():
        used.update(abs(int(x)) for x in s.split(","))
    used.update(baglot)
    for prof, skill, item, yld, recipe, reagents in recipes.values():
        if item:
            used.add(item)
        used.update(r for r, _ in reagents)
        if recipe:
            used.add(recipe)
    items_out = {i: f"{quality[i]}|{clean(iname[i])}" for i in used if i in iname}

    os.makedirs(a.out_dir, exist_ok=True)
    path1 = os.path.join(a.out_dir, "MobLootData.lua")
    with open(path1, "w", encoding="utf-8") as fh:
        fh.write("-- Generated by gen_mobloot_data.py (AzerothCore base data)\n")
        write_table(fh, "MobLoot_Static", {k: loot_str(v) for k, v in drops.items()})
    path2 = os.path.join(a.out_dir, "MobLootInfo.lua")
    with open(path2, "w", encoding="utf-8") as fh:
        fh.write("-- Generated by gen_mobloot_data.py (AzerothCore base data)\n")
        write_table(fh, "MobLoot_Mobs", mobs)
        write_table(fh, "MobLoot_ItemInfo", items_out)
        write_table(fh, "MobLoot_Vend", {k: ",".join(map(str, v)) for k, v in vend.items()})
        write_table(fh, "MobLoot_Objs", objs)
        write_table(fh, "MobLoot_ObjLoot", {k: loot_str(v) for k, v in objloot.items()})
        write_table(fh, "MobLoot_BagLoot", {k: loot_str(v) for k, v in baglot.items()})
        write_table(fh, "MobLoot_Quests", qinfo)
        write_table(fh, "MobLoot_QuestRew", qrew)
        write_table(fh, "MobLoot_Craft", {
            sp: f"{prof}|{skill}|{item or ''}|{yld}|{recipe or ''}|" + " ".join(f"{r}:{c}" for r, c in reagents)
            for sp, (prof, skill, item, yld, recipe, reagents) in recipes.items()})
        write_table(fh, "MobLoot_Trainers", {sp: ",".join(map(str, cs)) for sp, cs in trainers.items()})
    mb = lambda f: os.path.getsize(f) / 1e6
    print(f"Done: {len(drops)} creature drop tables, {len(vend)} vendors, {len(objloot)} objects, "
          f"{len(baglot)} containers, {len(qrew)} quests, {len(items_out)} items,\n"
          f"      {len(recipes)} crafting recipes, {len(trainers)} with known trainers.")
    print(f"  {path1}: {mb(path1):.1f} MB\n  {path2}: {mb(path2):.1f} MB")
    if not a.keep_cache and os.path.isdir(cache):
        shutil.rmtree(cache, ignore_errors=True)       # only our own download folder
        print("Deleted download cache (use --keep-cache to keep it).")


if __name__ == "__main__":
    main()
