"""Read-only Supabase audit: GET only, table queries always LIMIT 0.

Reads the public client configuration, never .env or privileged credentials.
Does not create users, invoke RPCs, send notifications, or retrieve user rows.
"""

import concurrent.futures
import datetime
import json
from pathlib import Path
import re
import urllib.error
import urllib.parse
import urllib.request


ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "docs" / "auditoria_sprint2" / "verificacion_api.json"


def main():
    config = (ROOT / "lib/core/supabase/supabase_config.dart").read_text(encoding="utf-8")
    url = re.search(r"static const url\s*=\s*'([^']+)'", config).group(1)
    key = re.search(r"static const anonKey\s*=\s*'([^']+)'", config).group(1)
    schema = json.loads((ROOT / "scripts/er_diagram/schema_physical.json").read_text(encoding="utf-8"))
    headers = {"apikey": key, "Authorization": f"Bearer {key}"}

    def get(path, accept="application/json"):
        request = urllib.request.Request(url + path, headers={**headers, "Accept": accept}, method="GET")
        try:
            with urllib.request.urlopen(request, timeout=15) as response:
                return response.status, json.loads(response.read())
        except urllib.error.HTTPError as error:
            try:
                payload = json.loads(error.read())
            except (ValueError, UnicodeError):
                payload = {}
            return error.code, {"code": payload.get("code"), "message": payload.get("message")}
        except (urllib.error.URLError, TimeoutError, OSError):
            return None, {"error": "network_unavailable"}

    def check_table(table):
        name = table["name"]
        columns = [column["name"] for column in table["columns"]]
        query = urllib.parse.urlencode({"select": ",".join(columns), "limit": 0})
        status, payload = get(f"/rest/v1/{name}?{query}")
        result = {"table": name, "requested_columns": columns, "http_status": status,
                  "column_names_resolve": status == 200,
                  "returned_rows": len(payload) if isinstance(payload, list) else None}
        if status != 200:
            result["error"] = payload
            if status is not None:
                checks = []
                for column in columns:
                    status_one, body_one = get(f"/rest/v1/{name}?" + urllib.parse.urlencode({"select": column, "limit": 0}))
                    if status_one != 200:
                        checks.append({"column": column, "http_status": status_one, "error": body_one})
                result["unresolved_columns"] = checks
        return result

    tables = schema["tables"] + [{"name": "public_profiles", "columns": [{"name": name} for name in
        ["id", "full_name", "avatar_url", "role", "points", "residence_type", "origin_country_code", "origin_city", "origin_municipality", "bio"]]}]
    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as executor:
        checks = list(executor.map(check_table, tables))

    settings_status, settings = get("/auth/v1/settings")
    auth = {"http_status": settings_status}
    if settings_status == 200:
        auth.update({name: settings.get(name) for name in ["disable_signup", "mailer_autoconfirm", "phone_autoconfirm", "external"]})
    else:
        auth["error"] = settings

    openapi_status, openapi = get("/rest/v1/", "application/openapi+json")
    paths = openapi.get("paths", {}) if openapi_status == 200 else {}
    rpcs = sorted(path.removeprefix("/rpc/") for path in paths if path.startswith("/rpc/"))
    output = {"checked_at_utc": datetime.datetime.now(datetime.timezone.utc).isoformat(),
              "project_host": urllib.parse.urlparse(url).hostname,
              "method": "GET; PostgREST explicit SELECT columns LIMIT 0, Auth public settings, OpenAPI metadata",
              "limits": "Does not verify writes, RLS behavior, triggers, FK, storage uploads, deployed Edge Functions, or realtime events. OpenAPI RPC absence with anon is inconclusive.",
              "tables": checks, "auth_public_settings": auth,
              "openapi": {"http_status": openapi_status, "rpc_names_visible_to_anon": rpcs}}
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(json.dumps(output, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"output": str(OUTPUT), "tables_checked": len(checks),
                      "tables_with_all_requested_columns": sum(check["column_names_resolve"] for check in checks),
                      "unresolved": [{"table": check["table"], "error": check.get("error"), "columns": check.get("unresolved_columns")} for check in checks if not check["column_names_resolve"]],
                      "auth_public_settings": auth, "openapi_status": openapi_status,
                      "rpc_names_visible_to_anon": rpcs}, ensure_ascii=False, indent=2))
    if any(check["http_status"] is None for check in checks):
        raise SystemExit(2)


if __name__ == "__main__":
    main()
