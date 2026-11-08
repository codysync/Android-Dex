#!/usr/bin/env python3
"""dex-edge: local stand-in for every host Android DEX talks to.

Serves https://api.github.com (update check), https://ipinfo.io (IP/geo widget) and
https://api.weatherapi.com + https://cdn.weatherapi.com (weather widget) on 127.0.0.1:443,
so the app needs no third party and no DNS. Content is local: the update answer comes from
selfhost/manifest.json, the weather is a static scene kept in weather.json.

Hosts entries + our CA are installed by install-edge.sh.
"""
import json
import pathlib
import sys
import ssl
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

ROOT = pathlib.Path(__file__).resolve().parent
STATE = pathlib.Path.home() / ".local/state/dex-edge"
MANIFEST = ROOT.parent / "manifest.json"
SITE = "https://oracle.skink-tailor.ts.net:8799/"
ICONS = ROOT / "icons"

DEFAULT_WEATHER = {
    "location": {"name": "Brisbane", "region": "Queensland", "country": "Australia",
                 "lat": -27.47, "lon": 153.03, "tz_id": "Australia/Brisbane"},
    "condition": {"text": "Partly cloudy", "code": 1006, "icon": "116"},
    "temp_c": 24.0, "is_day": 1, "humidity": 58, "wind_kph": 11.0,
    "feelslike_c": 25.2, "pressure_mb": 1014.0, "uv": 7.0,
}


def weather_cfg():
    cfg = json.loads(json.dumps(DEFAULT_WEATHER))
    try:
        cfg.update(json.loads((STATE / "weather.json").read_text()))
    except (OSError, ValueError):
        pass
    return cfg


def condition(cfg):
    code = str(cfg["condition"]["code"])
    daynight = "day" if cfg.get("is_day") else "night"
    return {"text": cfg["condition"]["text"], "code": int(code),
            "icon": f"//cdn.weatherapi.com/weather/64x64/{daynight}/{cfg['condition']['icon']}.png"}


def current(cfg):
    return {"temp_c": cfg["temp_c"], "temp_f": round(cfg["temp_c"] * 9 / 5 + 32, 1),
            "is_day": cfg["is_day"], "condition": condition(cfg),
            "wind_kph": cfg["wind_kph"], "humidity": cfg["humidity"],
            "feelslike_c": cfg["feelslike_c"], "pressure_mb": cfg["pressure_mb"],
            "uv": cfg["uv"], "cloud": 25, "precip_mm": 0.0,
            "last_updated_epoch": int(time.time())}


def location(cfg):
    loc = dict(cfg["location"])
    loc.update({"localtime_epoch": int(time.time()),
                "localtime": time.strftime("%Y-%m-%d %H:%M")})
    return loc


class Handler(BaseHTTPRequestHandler):
    server_version = "dex-edge"

    def log_message(self, fmt, *a):  # one line per request into the journal
        print(f"{self.address_string()} {self.headers.get('Host', '-')} {fmt % a}", flush=True)

    def send_json(self, obj, code=200):
        body = json.dumps(obj).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def send_file(self, path):
        if not path.is_file():
            self.send_json({"error": {"message": "not found"}}, 404)
            return
        data = path.read_bytes()
        self.send_response(200)
        self.send_header("Content-Type", "image/png")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self):
        path, _, query = self.path.partition("?")
        host = (self.headers.get("Host") or "").split(":")[0]

        if host == "api.github.com" and path.endswith("/releases/latest"):
            tag = json.loads(MANIFEST.read_text())["tag"] if MANIFEST.is_file() else "Android-Dex-v.1.5"
            return self.send_json({"tag_name": tag, "name": tag,
                                   "html_url": SITE, "assets": []})
        if host == "ipinfo.io":
            cfg = weather_cfg()
            return self.send_json({"ip": "100.108.225.1", "hostname": "oracle",
                                   "city": cfg["location"]["name"],
                                   "region": cfg["location"]["region"],
                                   "country": "AU", "org": "homelab",
                                   "loc": f"{cfg['location']['lat']},{cfg['location']['lon']}",
                                   "timezone": cfg["location"]["tz_id"],
                                   "readme": "served by dex-edge, no ipinfo.io request"})
        if host == "api.weatherapi.com":
            cfg = weather_cfg()
            if path.startswith("/v1/current.json"):
                return self.send_json({"location": location(cfg), "current": current(cfg)})
            if path.startswith("/v1/forecast.json"):
                fc = [{"date": time.strftime("%Y-%m-%d", time.localtime(time.time() + d * 86400)),
                       "day": {"maxtemp_c": cfg["temp_c"] + 2, "mintemp_c": cfg["temp_c"] - 6,
                               "avgtemp_c": cfg["temp_c"], "condition": condition(cfg)},
                       "hour": []} for d in range(3)]
                return self.send_json({"location": location(cfg), "current": current(cfg),
                                       "forecast": {"forecastday": fc}})
            return self.send_json({"error": {"message": "dex-edge: no such path"}}, 404)
        if host == "cdn.weatherapi.com":
            return self.send_file(ICONS / path.lstrip("/"))
        return self.send_json({"error": {"message": f"dex-edge: unmapped host {host}"}}, 404)


class Server(ThreadingHTTPServer):
    def handle_error(self, request, client_address):
        exc = sys.exc_info()[1]
        print(f"error from {client_address}: {exc!r}", flush=True)


def main():
    ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    ctx.load_cert_chain(STATE / "fullchain.pem", STATE / "leaf.key")
    srv = Server(("127.0.0.1", 443), Handler)
    srv.socket = ctx.wrap_socket(srv.socket, server_side=True)
    print("dex-edge listening on 127.0.0.1:443", flush=True)
    srv.serve_forever()


if __name__ == "__main__":
    main()
