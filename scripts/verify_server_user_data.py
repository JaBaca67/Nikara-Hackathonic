"""Read-only checks for migration 049; never retrieves user records."""
import concurrent.futures
import datetime
import json
from pathlib import Path
import re
import urllib.error
import urllib.parse
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
CHECKS = {
    "profiles": "username,trip_alerts,eco_campaigns,offers,public_profile",
    "public_profiles": "username",
    "businesses": "favorites_count",
    "passport_trips": "user_id,trip_id,business_id,started_at,completed_at,postcard",
    "route_visit_progress": "user_id,route_id,visit_key,status,updated_at",
    "assistant_conversations": "id,user_id,title,messages,updated_at",
}

def main():
    config = (ROOT / "lib/core/supabase/supabase_config.dart").read_text(encoding="utf-8")
    url = re.search(r"static const url\s*=\s*'([^']+)'", config).group(1)
    key = re.search(r"static const anonKey\s*=\s*'([^']+)'", config).group(1)
    def check(item):
        table, columns = item
        path = "/rest/v1/" + table + "?" + urllib.parse.urlencode({"select": columns, "limit": 0})
        request = urllib.request.Request(url + path, headers={"apikey": key, "Authorization": "Bearer " + key}, method="GET")
        try:
            with urllib.request.urlopen(request, timeout=20) as response:
                status, body = response.status, json.loads(response.read())
        except urllib.error.HTTPError as error:
            status, body = error.code, json.loads(error.read())
        except (urllib.error.URLError, TimeoutError, OSError):
            status, body = None, {"code": "NETWORK", "message": "No connection"}
        return {"table": table, "columns": columns, "http_status": status,
                "error": {k: body.get(k) for k in ("code", "message")} if isinstance(body, dict) else None,
                "rows_returned": len(body) if isinstance(body, list) else None}
    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
        results = list(pool.map(check, CHECKS.items()))
    output = {"checked_at_utc": datetime.datetime.now(datetime.timezone.utc).isoformat(),
              "project_host": urllib.parse.urlparse(url).hostname,
              "method": "GET explicit columns LIMIT 0 with public anon key",
              "limits": "401/403 may only mean access is restricted. These checks do not validate authenticated writes, RLS isolation, SQL triggers, RPC behavior or device Realtime delivery.",
              "checks": results}
    path = ROOT / "docs/auditoria_sprint2/verificacion_datos_remotos.json"
    path.write_text(json.dumps(output, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"output": str(path), "checks": results}, ensure_ascii=False, indent=2))

if __name__ == "__main__":
    main()
