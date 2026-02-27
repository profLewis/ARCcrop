#!/usr/bin/env python3
"""
ARCcrop Source Registry — Discovery, Validation & Speed Test

Reads source_registry.json and:
  - Discovers new years of data via WMS GetCapabilities XML parsing
  - Probes URL-templated sources for new years via HEAD/GET
  - Health-checks all endpoints (latency, HTTP status)
  - Tests alternative mirrors for the same dataset
  - Produces an actionable report with suggested changes
  - Optionally updates source_registry.json timestamps/years
  - Optionally generates Swift/Python code patches

Usage:
    python check_sources.py                          # Check all, print report
    python check_sources.py --update                 # + write updated registry
    python check_sources.py --source usda_cdl        # Single source
    python check_sources.py --codegen                # Print Swift/Python patches
    python check_sources.py --codegen --apply        # Apply patches in-place
    python check_sources.py --speed-test             # Benchmark alternative mirrors
    python check_sources.py --verbose                # Show HTTP/XML details

Dependencies: aiohttp (pip install aiohttp)
"""

import asyncio
import aiohttp
import argparse
import json
import os
import re
import sys
import time
import xml.etree.ElementTree as ET
from datetime import datetime, timezone
from urllib.parse import urlparse

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
REGISTRY_PATH = os.path.join(SCRIPT_DIR, "source_registry.json")
PROJECT_ROOT = os.path.dirname(SCRIPT_DIR)
SWIFT_SOURCE = os.path.join(PROJECT_ROOT, "ARCcrop", "Models", "CropMapSource.swift")
PYTHON_OVERVIEW = os.path.join(SCRIPT_DIR, "generate_overview_tiles.py")

CURRENT_YEAR = datetime.now().year
TIMEOUT = aiohttp.ClientTimeout(total=45)
MAX_HOST_CONCURRENT = 2   # per-host semaphore
MAX_GLOBAL_CONCURRENT = 6 # global semaphore

# Known alternative WMS mirrors for the same datasets.
# Each entry: list of {url, layers_template, label} dicts.
ALTERNATIVE_MIRRORS = {
    "usda_cdl": [
        {
            "label": "GMU CropScape (primary)",
            "base_url": "https://nassgeodata.gmu.edu/CropScapeService/wms_cdlall.cgi",
            "layers": "cdl_{year}",
            "crs": "EPSG:4326",
            "wms_version": "1.1.1",
        },
    ],
    "esa_worldcover": [
        {
            "label": "Terrascope (primary)",
            "base_url": "https://services.terrascope.be/wms/v2",
            "layers": "WORLDCOVER_2021_MAP",
            "crs": "EPSG:3857",
            "wms_version": "1.1.1",
        },
        {
            "label": "ESA WorldCover Viewer",
            "base_url": "https://viewer.esa-worldcover.org/wms",
            "layers": "WORLDCOVER_2021_MAP",
            "crs": "EPSG:3857",
            "wms_version": "1.1.1",
        },
    ],
    "jrc_eucropmap": [
        {
            "label": "JRC JEODPP (primary)",
            "base_url": "https://jeodpp.jrc.ec.europa.eu/jeodpp/services/ows/wms/landcover/eucropmap",
            "layers": "LC.EUCROPMAP.2022",
            "crs": "EPSG:3857",
            "wms_version": "1.1.1",
        },
    ],
    "brp_netherlands": [
        {
            "label": "PDOK (primary)",
            "base_url": "https://service.pdok.nl/rvo/brpgewaspercelen/wms/v1_0",
            "layers": "BrpGewas",
            "crs": "EPSG:3857",
            "wms_version": "1.3.0",
        },
    ],
    "rpg_france": [
        {
            "label": "Géoplateforme (primary)",
            "base_url": "https://data.geopf.fr/wms-r/wms",
            "layers": "LANDUSE.AGRICULTURE.LATEST",
            "crs": "EPSG:3857",
            "wms_version": "1.3.0",
        },
    ],
}


# ─── Utility ──────────────────────────────────────────────────────────

def strip_ns(tag):
    """Remove XML namespace prefix: {http://...}Name -> Name"""
    return tag.split("}")[-1] if "}" in tag else tag


def parse_layers_from_xml(xml_text, verbose=False):
    """Parse WMS GetCapabilities XML, return set of layer names."""
    layers = set()
    try:
        root = ET.fromstring(xml_text)
    except ET.ParseError as e:
        if verbose:
            print(f"  XML parse error: {e}")
        return layers

    for elem in root.iter():
        tag = strip_ns(elem.tag)
        if tag == "Layer":
            name_elem = None
            for child in elem:
                if strip_ns(child.tag) == "Name":
                    name_elem = child
                    break
            if name_elem is not None and name_elem.text:
                layers.add(name_elem.text.strip())
    return layers


def build_getcap_url(base_url, wms_version="1.1.1"):
    sep = "&" if "?" in base_url else "?"
    return f"{base_url}{sep}SERVICE=WMS&REQUEST=GetCapabilities&VERSION={wms_version}"


def build_getmap_url(base_url, layers, crs, wms_version, bbox, width=256, height=256):
    """Build a minimal GetMap URL for speed testing."""
    sep = "&" if "?" in base_url else "?"
    srs_key = "CRS" if wms_version == "1.3.0" else "SRS"
    return (
        f"{base_url}{sep}SERVICE=WMS&REQUEST=GetMap"
        f"&VERSION={wms_version}&LAYERS={layers}"
        f"&{srs_key}={crs}&BBOX={bbox}"
        f"&WIDTH={width}&HEIGHT={height}"
        f"&FORMAT=image/png&TRANSPARENT=TRUE"
    )


def host_from_url(url):
    return urlparse(url).hostname or "unknown"


# ─── Semaphore management ────────────────────────────────────────────

_host_sems = {}

def get_host_sem(host):
    if host not in _host_sems:
        _host_sems[host] = asyncio.Semaphore(MAX_HOST_CONCURRENT)
    return _host_sems[host]


# ─── Check functions ─────────────────────────────────────────────────

class SourceResult:
    """Holds the result of checking a single source."""
    def __init__(self, source_id, name, method):
        self.source_id = source_id
        self.name = name
        self.method = method
        self.status = "UNKNOWN"   # OK, TIMEOUT, ERROR, SKIPPED, NOT_AVAILABLE
        self.latency_ms = None
        self.current_years = None  # list from registry
        self.discovered_years = None  # list from discovery
        self.new_years = []        # years found that weren't known
        self.removed_years = []    # years in registry but not on server
        self.all_layers = []       # all layer names found (verbose)
        self.error = None
        self.notes = ""
        self.mirror_results = []   # [{label, latency_ms, status}]


async def check_getcapabilities_source(
    session, global_sem, source_id, source, verbose=False
):
    """Fetch GetCapabilities and regex-match layers to discover years."""
    result = SourceResult(source_id, source["name"], "GetCap")
    result.current_years = source.get("available_years") or []

    base_url = source["wms_base_url"]
    if not base_url:
        result.status = "SKIPPED"
        result.notes = "No WMS URL"
        return result

    url = build_getcap_url(base_url, source.get("wms_version", "1.1.1"))
    host = host_from_url(base_url)
    host_sem = get_host_sem(host)

    try:
        async with global_sem, host_sem:
            t0 = time.monotonic()
            async with session.get(url, timeout=TIMEOUT) as resp:
                raw = await resp.read()
                elapsed = (time.monotonic() - t0) * 1000
                result.latency_ms = round(elapsed)

                if resp.status != 200:
                    result.status = "ERROR"
                    result.error = f"HTTP {resp.status}"
                    return result
                # Try UTF-8, fall back to latin-1 (some EU WMS servers)
                try:
                    text = raw.decode("utf-8")
                except UnicodeDecodeError:
                    text = raw.decode("latin-1")
    except asyncio.TimeoutError:
        result.status = "TIMEOUT"
        result.error = ">45s"
        return result
    except Exception as e:
        result.status = "ERROR"
        result.error = str(e)[:120]
        return result

    layers = parse_layers_from_xml(text, verbose)
    result.all_layers = sorted(layers)

    if verbose:
        print(f"  [{source_id}] {len(layers)} layers from {host}")

    regex = source.get("layer_regex")
    if not regex:
        result.status = "OK"
        result.notes = f"{len(layers)} layers (no regex)"
        return result

    pattern = re.compile(regex)
    discovered_years = set()
    for layer_name in layers:
        m = pattern.match(layer_name)
        if m and m.lastindex and m.lastindex >= 1:
            val = m.group(1)
            # Could be a year (2024) or version string (V1)
            if val.isdigit() and len(val) == 4:
                discovered_years.add(int(val))

    result.discovered_years = sorted(discovered_years) if discovered_years else None
    current_set = set(result.current_years)

    if discovered_years:
        result.new_years = sorted(discovered_years - current_set)
        result.removed_years = sorted(current_set - discovered_years)
    else:
        # Regex matched nothing — might be version-based layers
        matching = [l for l in layers if pattern.match(l)]
        if matching:
            result.notes = f"Regex matches: {matching[:5]}"
        else:
            result.notes = f"Regex '{regex}' matched no layers"

    result.status = "OK"
    return result


async def check_probe_url_source(
    session, global_sem, source_id, source, verbose=False
):
    """Probe year-templated URLs via HEAD requests."""
    result = SourceResult(source_id, source["name"], "Probe")
    result.current_years = source.get("available_years") or []
    current_set = set(result.current_years)

    template = source.get("probe_url_template")
    if not template:
        result.status = "SKIPPED"
        result.notes = "No probe URL template"
        return result

    probe_range = source.get("probe_year_range", [2009, CURRENT_YEAR + 1])
    years_to_probe = range(probe_range[0], min(probe_range[1] + 1, CURRENT_YEAR + 2))

    base_url = source["wms_base_url"] or template
    host = host_from_url(base_url)
    host_sem = get_host_sem(host)

    discovered = set()
    first_latency = None

    for year in years_to_probe:
        url = template.replace("{year}", str(year))
        try:
            async with global_sem, host_sem:
                t0 = time.monotonic()
                async with session.get(url, timeout=TIMEOUT) as resp:
                    elapsed = (time.monotonic() - t0) * 1000
                    if first_latency is None:
                        first_latency = round(elapsed)
                    if resp.status == 200:
                        # Quick check: valid XML response (not error page)
                        text = await resp.text()
                        if "<WMS_Capabilities" in text or "<WMT_MS_Capabilities" in text:
                            discovered.add(year)
                            if verbose:
                                print(f"  [{source_id}] year {year}: OK ({round(elapsed)}ms)")
                        else:
                            if verbose:
                                print(f"  [{source_id}] year {year}: HTTP 200 but not WMS XML")
                    else:
                        if verbose:
                            print(f"  [{source_id}] year {year}: HTTP {resp.status}")
        except asyncio.TimeoutError:
            if verbose:
                print(f"  [{source_id}] year {year}: TIMEOUT")
        except Exception as e:
            if verbose:
                print(f"  [{source_id}] year {year}: {e}")

    result.latency_ms = first_latency
    result.discovered_years = sorted(discovered) if discovered else None
    result.new_years = sorted(discovered - current_set)
    result.removed_years = sorted(current_set - discovered) if discovered else []
    result.status = "OK" if discovered else "ERROR"
    if not discovered:
        result.error = "No valid years found"
    return result


async def check_fixed_source(
    session, global_sem, source_id, source, verbose=False
):
    """Health-check a fixed-layer source via GetCapabilities."""
    result = SourceResult(source_id, source["name"], "Fixed")

    base_url = source.get("wms_base_url")
    if not base_url:
        result.status = "SKIPPED"
        result.notes = "No WMS URL"
        return result

    url = build_getcap_url(base_url, source.get("wms_version", "1.1.1"))
    host = host_from_url(base_url)
    host_sem = get_host_sem(host)

    try:
        async with global_sem, host_sem:
            t0 = time.monotonic()
            async with session.get(url, timeout=TIMEOUT) as resp:
                elapsed = (time.monotonic() - t0) * 1000
                result.latency_ms = round(elapsed)
                if resp.status == 200:
                    raw = await resp.read()
                    try:
                        text = raw.decode("utf-8")
                    except UnicodeDecodeError:
                        text = raw.decode("latin-1")
                    layers = parse_layers_from_xml(text, verbose)
                    result.all_layers = sorted(layers)
                    result.status = "OK"
                    result.notes = f"{len(layers)} layers"

                    # Check that the expected layer actually exists
                    expected = source.get("wms_layers", "")
                    if expected and expected not in layers:
                        result.notes += f" ⚠ expected '{expected}' NOT FOUND"
                else:
                    result.status = "ERROR"
                    result.error = f"HTTP {resp.status}"
    except asyncio.TimeoutError:
        result.status = "TIMEOUT"
        result.error = ">45s"
    except Exception as e:
        result.status = "ERROR"
        result.error = str(e)[:120]

    return result


async def check_not_available_source(source_id, source):
    """Flag sources with no WMS endpoint."""
    result = SourceResult(source_id, source["name"], "N/A")
    result.status = "NOT_AVAILABLE"
    result.notes = source.get("notes", "")
    return result


async def check_non_wms(session, global_sem, key, config, verbose=False):
    """Check non-WMS endpoints (FAO API, FTW PMTiles)."""
    result = SourceResult(key, config["name"], config["check_type"])

    url = config["check_url"]
    host = host_from_url(url)
    host_sem = get_host_sem(host)

    try:
        method = "HEAD" if config["check_type"] == "head_request" else "GET"
        async with global_sem, host_sem:
            t0 = time.monotonic()
            if method == "HEAD":
                async with session.head(url, timeout=TIMEOUT) as resp:
                    elapsed = (time.monotonic() - t0) * 1000
                    result.latency_ms = round(elapsed)
                    if resp.status == 200:
                        result.status = "OK"
                        cl = resp.headers.get("Content-Length")
                        if cl:
                            mb = int(cl) / (1024 * 1024)
                            result.notes = f"{mb:.1f} MB"
                    else:
                        result.status = "ERROR"
                        result.error = f"HTTP {resp.status}"
            else:
                async with session.get(url, timeout=TIMEOUT) as resp:
                    elapsed = (time.monotonic() - t0) * 1000
                    result.latency_ms = round(elapsed)
                    if resp.status == 200:
                        data = await resp.json()
                        count = len(data) if isinstance(data, list) else "?"
                        expected = config.get("expected_min_size", 0)
                        if isinstance(count, int) and count >= expected:
                            result.status = "OK"
                            result.notes = f"{count} entries"
                        else:
                            result.status = "WARNING"
                            result.notes = f"{count} entries (expected ≥{expected})"
                    else:
                        result.status = "ERROR"
                        result.error = f"HTTP {resp.status}"
    except asyncio.TimeoutError:
        result.status = "TIMEOUT"
        result.error = ">45s"
    except Exception as e:
        result.status = "ERROR"
        result.error = str(e)[:120]

    return result


# ─── Speed test: fetch a sample tile from each mirror ────────────────

async def speed_test_mirror(session, global_sem, mirror, verbose=False):
    """Fetch a sample GetMap tile and measure latency."""
    base_url = mirror["base_url"]
    layers = mirror["layers"]
    crs = mirror.get("crs", "EPSG:3857")
    wms_version = mirror.get("wms_version", "1.1.1")

    # Sample tile: central Europe, roughly zoom 5
    if crs == "EPSG:4326":
        bbox = "-10,35,30,60"
    else:
        bbox = "-1113194,4163881,3339584,8399738"

    url = build_getmap_url(base_url, layers, crs, wms_version, bbox)
    host = host_from_url(base_url)
    host_sem = get_host_sem(host)

    try:
        async with global_sem, host_sem:
            t0 = time.monotonic()
            async with session.get(url, timeout=TIMEOUT) as resp:
                data = await resp.read()
                elapsed = (time.monotonic() - t0) * 1000
                if resp.status == 200 and len(data) > 100:
                    return {"label": mirror["label"], "latency_ms": round(elapsed), "status": "OK", "size": len(data)}
                else:
                    return {"label": mirror["label"], "latency_ms": round(elapsed), "status": f"HTTP {resp.status}", "size": 0}
    except asyncio.TimeoutError:
        return {"label": mirror["label"], "latency_ms": None, "status": "TIMEOUT", "size": 0}
    except Exception as e:
        return {"label": mirror["label"], "latency_ms": None, "status": str(e)[:80], "size": 0}


async def run_speed_tests(session, global_sem, verbose=False):
    """Run speed tests for all alternative mirrors."""
    results = {}
    tasks = []
    for source_id, mirrors in ALTERNATIVE_MIRRORS.items():
        for mirror in mirrors:
            tasks.append((source_id, speed_test_mirror(session, global_sem, mirror, verbose)))

    coros = [t[1] for t in tasks]
    outcomes = await asyncio.gather(*coros, return_exceptions=True)

    for (source_id, _), outcome in zip(tasks, outcomes):
        if isinstance(outcome, Exception):
            outcome = {"label": "?", "latency_ms": None, "status": str(outcome)[:80], "size": 0}
        results.setdefault(source_id, []).append(outcome)

    return results


# ─── Coalesce GetCapabilities fetches by host ────────────────────────

async def run_all_checks(registry, source_filter=None, verbose=False, do_speed_test=False):
    """Run all checks and return list of SourceResult."""
    results = []

    connector = aiohttp.TCPConnector(limit=12, limit_per_host=3, ttl_dns_cache=300)
    global_sem = asyncio.Semaphore(MAX_GLOBAL_CONCURRENT)

    async with aiohttp.ClientSession(connector=connector) as session:
        sources = registry["sources"]
        tasks = []

        # Group GetCapabilities sources by base URL to coalesce fetches
        getcap_hosts = {}
        for sid, src in sources.items():
            if source_filter and sid != source_filter:
                continue
            method = src.get("year_discovery", "fixed")
            if method == "getcapabilities_regex" and src.get("wms_base_url"):
                host = src["wms_base_url"]
                getcap_hosts.setdefault(host, []).append((sid, src))

        # For coalesced hosts, only fetch GetCapabilities once
        getcap_cache = {}
        coalesced_sids = set()

        for base_url, group in getcap_hosts.items():
            # Use the first source's WMS version
            wms_version = group[0][1].get("wms_version", "1.1.1")
            coalesced_sids.update(sid for sid, _ in group)

            async def fetch_and_parse(url, ver, grp):
                url_full = build_getcap_url(url, ver)
                host = host_from_url(url)
                host_sem = get_host_sem(host)
                results_local = []
                try:
                    async with global_sem, host_sem:
                        t0 = time.monotonic()
                        async with session.get(url_full, timeout=TIMEOUT) as resp:
                            raw = await resp.read()
                            elapsed = (time.monotonic() - t0) * 1000
                            latency = round(elapsed)
                            if resp.status != 200:
                                for sid, src in grp:
                                    r = SourceResult(sid, src["name"], "GetCap")
                                    r.status = "ERROR"
                                    r.error = f"HTTP {resp.status}"
                                    r.latency_ms = latency
                                    r.current_years = src.get("available_years") or []
                                    results_local.append(r)
                                return results_local

                    try:
                        text = raw.decode("utf-8")
                    except UnicodeDecodeError:
                        text = raw.decode("latin-1")
                    layers = parse_layers_from_xml(text, verbose)
                    if verbose:
                        print(f"  Coalesced fetch: {host} → {len(layers)} layers")

                    for sid, src in grp:
                        r = SourceResult(sid, src["name"], "GetCap")
                        r.latency_ms = latency
                        r.current_years = src.get("available_years") or []
                        r.all_layers = sorted(layers)

                        regex = src.get("layer_regex")
                        if regex:
                            pattern = re.compile(regex)
                            discovered = set()
                            matched_layers = []
                            for layer_name in layers:
                                m = pattern.match(layer_name)
                                if m:
                                    matched_layers.append(layer_name)
                                    if m.lastindex and m.lastindex >= 1:
                                        val = m.group(1)
                                        if val.isdigit() and len(val) == 4:
                                            discovered.add(int(val))

                            if discovered:
                                r.discovered_years = sorted(discovered)
                                current_set = set(r.current_years)
                                r.new_years = sorted(discovered - current_set)
                                r.removed_years = sorted(current_set - discovered)
                            else:
                                if matched_layers:
                                    r.notes = f"Regex matches: {matched_layers[:5]}"
                                else:
                                    r.notes = f"Regex '{regex}' matched no layers"
                        else:
                            r.notes = f"{len(layers)} layers (no regex)"

                        r.status = "OK"
                        results_local.append(r)

                except asyncio.TimeoutError:
                    for sid, src in grp:
                        r = SourceResult(sid, src["name"], "GetCap")
                        r.status = "TIMEOUT"
                        r.error = ">45s"
                        r.current_years = src.get("available_years") or []
                        results_local.append(r)
                except Exception as e:
                    for sid, src in grp:
                        r = SourceResult(sid, src["name"], "GetCap")
                        r.status = "ERROR"
                        r.error = str(e)[:120]
                        r.current_years = src.get("available_years") or []
                        results_local.append(r)

                return results_local

            tasks.append(fetch_and_parse(base_url, wms_version, group))

        # Non-coalesced sources
        for sid, src in sources.items():
            if source_filter and sid != source_filter:
                continue
            if sid in coalesced_sids:
                continue

            method = src.get("year_discovery", "fixed")
            if method == "getcapabilities_regex":
                tasks.append(check_getcapabilities_source(session, global_sem, sid, src, verbose))
            elif method == "probe_url":
                tasks.append(check_probe_url_source(session, global_sem, sid, src, verbose))
            elif method == "not_available":
                tasks.append(check_not_available_source(sid, src))
            else:  # fixed
                tasks.append(check_fixed_source(session, global_sem, sid, src, verbose))

        # Non-WMS checks
        non_wms = registry.get("non_wms_checks", {})
        for key, cfg in non_wms.items():
            if source_filter and key != source_filter:
                continue
            tasks.append(check_non_wms(session, global_sem, key, cfg, verbose))

        # Run all tasks concurrently
        outcomes = await asyncio.gather(*tasks, return_exceptions=True)

        for outcome in outcomes:
            if isinstance(outcome, list):
                results.extend(outcome)
            elif isinstance(outcome, SourceResult):
                results.append(outcome)
            elif isinstance(outcome, Exception):
                print(f"  Task exception: {outcome}")

        # Speed tests
        speed_results = {}
        if do_speed_test:
            speed_results = await run_speed_tests(session, global_sem, verbose)

    return results, speed_results


# ─── Report builder ──────────────────────────────────────────────────

def build_report(results, speed_results=None):
    """Build a formatted text report from check results."""
    now = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    lines = []
    lines.append(f"{'='*64}")
    lines.append(f"  ARCcrop Source Check — {now}")
    lines.append(f"{'='*64}")
    lines.append("")

    # --- Year Discovery ---
    discovery_results = [r for r in results if r.discovered_years is not None or r.new_years]
    if discovery_results:
        lines.append("--- Year Discovery ---")
        lines.append(f"{'Source':<24} {'Method':<8} {'Current':<18} {'Discovered':<18} {'Action'}")
        lines.append("-" * 90)
        for r in sorted(discovery_results, key=lambda x: x.source_id):
            current_str = _year_range_str(r.current_years) if r.current_years else "—"
            disc_str = _year_range_str(r.discovered_years) if r.discovered_years else "—"
            if r.new_years:
                action = f"NEW: {', '.join(str(y) for y in r.new_years)}"
            elif r.removed_years:
                action = f"REMOVED: {', '.join(str(y) for y in r.removed_years)}"
            else:
                action = "unchanged"
            lines.append(f"{r.source_id:<24} {r.method:<8} {current_str:<18} {disc_str:<18} {action}")
        lines.append("")

    # --- Sources with no changes ---
    unchanged = [r for r in results if r.status == "OK" and not r.new_years and r.method in ("GetCap", "Probe")]
    if unchanged:
        lines.append("--- Up to Date ---")
        for r in sorted(unchanged, key=lambda x: x.source_id):
            current_str = _year_range_str(r.current_years) if r.current_years else "—"
            lines.append(f"  {r.source_id:<24} {current_str:<18} OK ({r.latency_ms}ms)")
        lines.append("")

    # --- Endpoint Health ---
    lines.append("--- Endpoint Health ---")
    lines.append(f"{'Source':<24} {'Status':<10} {'Latency':<10} {'Note'}")
    lines.append("-" * 80)
    for r in sorted(results, key=lambda x: x.source_id):
        latency_str = f"{r.latency_ms}ms" if r.latency_ms else "—"
        note = r.error or r.notes or ""
        status_icon = {"OK": "OK", "TIMEOUT": "TIMEOUT", "ERROR": "ERROR",
                       "WARNING": "WARNING", "NOT_AVAILABLE": "N/A", "SKIPPED": "SKIP"}
        lines.append(f"{r.source_id:<24} {status_icon.get(r.status, r.status):<10} {latency_str:<10} {note[:50]}")
    lines.append("")

    # --- Not Available (flagged for future) ---
    na = [r for r in results if r.status == "NOT_AVAILABLE"]
    if na:
        lines.append("--- Not Available (flagged for future investigation) ---")
        for r in sorted(na, key=lambda x: x.source_id):
            lines.append(f"  {r.source_id:<24} {r.notes}")
        lines.append("")

    # --- Speed Test ---
    if speed_results:
        lines.append("--- Mirror Speed Test ---")
        lines.append(f"{'Source':<20} {'Mirror':<35} {'Status':<10} {'Latency':<10} {'Size'}")
        lines.append("-" * 90)
        for source_id in sorted(speed_results.keys()):
            for m in speed_results[source_id]:
                lat = f"{m['latency_ms']}ms" if m['latency_ms'] else "—"
                sz = f"{m['size']/1024:.1f}KB" if m['size'] else "—"
                lines.append(f"{source_id:<20} {m['label']:<35} {m['status']:<10} {lat:<10} {sz}")
        lines.append("")

    # --- Suggested Actions ---
    actions = []
    for r in sorted(results, key=lambda x: x.source_id):
        if r.new_years:
            for y in r.new_years:
                actions.append(f"Update {r.source_id} availableYears: add {y}")
            if r.discovered_years:
                max_disc = max(r.discovered_years)
                actions.append(f"Update {r.source_id} default_year → {max_disc}")
        if r.status == "TIMEOUT":
            actions.append(f"Investigate {r.source_id} timeout (may need new endpoint)")
        if r.status == "ERROR" and r.error:
            actions.append(f"Fix {r.source_id}: {r.error}")
        if r.notes and "NOT FOUND" in r.notes:
            actions.append(f"Layer mismatch for {r.source_id}: {r.notes}")

    if actions:
        lines.append("--- Suggested Actions ---")
        for i, action in enumerate(actions, 1):
            lines.append(f"  {i}. {action}")
        lines.append("")

    return "\n".join(lines)


def _year_range_str(years):
    """Compact year range: [2008,2009,...,2023] -> '2008-2023'"""
    if not years:
        return "—"
    if len(years) == 1:
        return str(years[0])
    return f"{min(years)}-{max(years)}"


# ─── Registry update ─────────────────────────────────────────────────

def update_registry(registry, results):
    """Update registry timestamps and discovered years."""
    now = datetime.now(timezone.utc).isoformat()
    registry["last_global_check"] = now

    for r in results:
        if r.source_id in registry["sources"]:
            src = registry["sources"][r.source_id]
            src["last_checked"] = now
            src["last_status"] = r.status

            if r.discovered_years:
                src["available_years"] = r.discovered_years
                src["default_year"] = max(r.discovered_years)

        elif r.source_id in registry.get("non_wms_checks", {}):
            cfg = registry["non_wms_checks"][r.source_id]
            cfg["last_checked"] = now
            cfg["last_status"] = r.status
            if hasattr(r, "notes") and r.notes:
                cfg["last_value"] = r.notes


# ─── Code generation ─────────────────────────────────────────────────

def generate_codegen(registry):
    """Generate Swift and Python code patches for year updates."""
    patches = {"swift": [], "python": []}

    for sid, src in registry["sources"].items():
        years = src.get("available_years")
        if not years or not src.get("swift_has_year_param"):
            continue

        swift_case = src.get("swift_enum_case")
        if not swift_case:
            continue

        min_y, max_y = min(years), max(years)

        # Swift: update availableYears range
        patches["swift"].append({
            "source_id": sid,
            "enum_case": swift_case,
            "range_str": f"{min_y}...{max_y}",
            "default_year": src.get("default_year", max_y),
        })

        # Python: update generate_overview_tiles.py years list
        patches["python"].append({
            "source_id": sid,
            "years_str": f"list(range({min_y}, {max_y + 1}))",
            "default_year": src.get("default_year", max_y),
        })

    return patches


def print_codegen(patches):
    """Print code patches to stdout."""
    print("\n--- Swift Patches (CropMapSource.swift) ---")
    print("Update `availableYears` switch cases:\n")
    for p in patches["swift"]:
        print(f"  case .{p['enum_case']}: {p['range_str']}")
    print()

    print("--- Python Patches (generate_overview_tiles.py) ---")
    print("Update WMS_SOURCES year lists:\n")
    for p in patches["python"]:
        print(f'  "{p["source_id"]}": years={p["years_str"]}, default_year={p["default_year"]}')
    print()


def apply_codegen(patches):
    """Apply code patches to Swift and Python source files."""
    applied = 0

    # Swift: update availableYears in CropMapSource.swift
    if os.path.exists(SWIFT_SOURCE):
        with open(SWIFT_SOURCE, "r") as f:
            swift = f.read()

        for p in patches["swift"]:
            # Match "case .enumCase: MIN...MAX" pattern
            pattern = rf"(case \.{p['enum_case']}:\s*)\d+\.\.\.\d+"
            replacement = rf"\g<1>{p['range_str']}"
            swift_new = re.sub(pattern, replacement, swift)
            if swift_new != swift:
                swift = swift_new
                applied += 1
                print(f"  Applied: {p['enum_case']} → {p['range_str']}")

        with open(SWIFT_SOURCE, "w") as f:
            f.write(swift)

    # Python: update years in generate_overview_tiles.py
    if os.path.exists(PYTHON_OVERVIEW):
        with open(PYTHON_OVERVIEW, "r") as f:
            python = f.read()

        for p in patches["python"]:
            # Match "years": list(range(...)) or "years": [...]
            # Look for the source block
            pattern = rf'("{p["source_id"]}".*?"years":\s*)list\(range\(\d+,\s*\d+\)\)'
            replacement = rf'\g<1>{p["years_str"]}'
            python_new = re.sub(pattern, replacement, python, flags=re.DOTALL)
            if python_new != python:
                python = python_new
                applied += 1
                print(f"  Applied: {p['source_id']} → {p['years_str']}")

        with open(PYTHON_OVERVIEW, "w") as f:
            f.write(python)

    print(f"\n  {applied} patches applied.")


# ─── Main ────────────────────────────────────────────────────────────

async def main():
    parser = argparse.ArgumentParser(
        description="ARCcrop Source Registry — Discovery, Validation & Speed Test"
    )
    parser.add_argument("--source", "-s", help="Check only this source ID")
    parser.add_argument("--update", "-u", action="store_true",
                        help="Update source_registry.json with results")
    parser.add_argument("--codegen", "-c", action="store_true",
                        help="Print Swift/Python code patches")
    parser.add_argument("--apply", "-a", action="store_true",
                        help="Apply code patches to source files (requires --codegen)")
    parser.add_argument("--speed-test", "-t", action="store_true",
                        help="Benchmark alternative mirrors")
    parser.add_argument("--verbose", "-v", action="store_true",
                        help="Show HTTP/XML details")
    parser.add_argument("--json", action="store_true",
                        help="Output results as JSON")
    args = parser.parse_args()

    if not os.path.exists(REGISTRY_PATH):
        print(f"Error: {REGISTRY_PATH} not found")
        sys.exit(1)

    with open(REGISTRY_PATH) as f:
        registry = json.load(f)

    print(f"Loading {len(registry['sources'])} sources from source_registry.json...")
    if args.source:
        print(f"Filtering to: {args.source}")
    print()

    results, speed_results = await run_all_checks(
        registry,
        source_filter=args.source,
        verbose=args.verbose,
        do_speed_test=args.speed_test,
    )

    if args.json:
        output = []
        for r in results:
            output.append({
                "source_id": r.source_id,
                "name": r.name,
                "method": r.method,
                "status": r.status,
                "latency_ms": r.latency_ms,
                "current_years": r.current_years,
                "discovered_years": r.discovered_years,
                "new_years": r.new_years,
                "error": r.error,
                "notes": r.notes,
            })
        print(json.dumps(output, indent=2))
    else:
        report = build_report(results, speed_results if args.speed_test else None)
        print(report)

    if args.update:
        update_registry(registry, results)
        with open(REGISTRY_PATH, "w") as f:
            json.dump(registry, f, indent=2)
        print(f"Updated {REGISTRY_PATH}")

    if args.codegen:
        # Re-read registry (may have been updated)
        with open(REGISTRY_PATH) as f:
            registry = json.load(f)
        patches = generate_codegen(registry)
        print_codegen(patches)
        if args.apply:
            apply_codegen(patches)


if __name__ == "__main__":
    asyncio.run(main())
