"""In-memory store for reported items, with input validation."""

import itertools
import re
import threading
from datetime import datetime, timezone

CATEGORIES = {"electronics", "id-card", "books", "clothing", "keys", "other"}
LOCATIONS = re.compile(r"^[A-Za-z0-9 .,'-]{2,60}$")


class ValidationError(ValueError):
    pass


class ItemStore:
    def __init__(self):
        self._items = {}
        self._ids = itertools.count(1)
        self._lock = threading.Lock()

    @staticmethod
    def _clean_text(value, field, max_len):
        if not isinstance(value, str) or not value.strip():
            raise ValidationError(f"'{field}' is required")
        value = value.strip()
        if len(value) > max_len:
            raise ValidationError(f"'{field}' must be at most {max_len} characters")
        return value

    def report(self, data):
        title = self._clean_text(data.get("title"), "title", 80)
        category = data.get("category", "other")
        if category not in CATEGORIES:
            raise ValidationError(f"'category' must be one of {sorted(CATEGORIES)}")
        location = self._clean_text(data.get("location"), "location", 60)
        if not LOCATIONS.match(location):
            raise ValidationError("'location' contains unsupported characters")
        with self._lock:
            item_id = next(self._ids)
            item = {
                "id": item_id,
                "title": title,
                "category": category,
                "location": location,
                "status": "found",
                "reported_at": datetime.now(timezone.utc).isoformat(timespec="seconds"),
            }
            self._items[item_id] = item
        return item

    def get(self, item_id):
        return self._items.get(item_id)

    def search(self, query=None, category=None):
        items = list(self._items.values())
        if category:
            items = [i for i in items if i["category"] == category]
        if query:
            q = query.lower()
            items = [i for i in items if q in i["title"].lower() or q in i["location"].lower()]
        return items

    def claim(self, item_id, claimant):
        claimant = self._clean_text(claimant, "claimant", 60)
        with self._lock:
            item = self._items.get(item_id)
            if item is None:
                return None
            if item["status"] == "claimed":
                raise ValidationError("item has already been claimed")
            item["status"] = "claimed"
            item["claimed_by"] = claimant
        return item
