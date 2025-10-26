#!/usr/bin/env python3
"""用于测试登录态接口的最小化脚本。"""

import argparse
import json
from urllib import error, request


BASE_URL = "http://43.128.47.234:3000"
LOGIN_REQUIRED_ENDPOINT = "/user/account"
DEFAULT_COOKIE = (
    "ntes_kaola_ad=1; WM_NI=ViKG7%2BAxLoeaNuN84q2C%2FEuYytlOHbHURZ3KpE3J2oxBddaRPutSv42AIhTyYtLrpk0BkWzuwSKlwCvO2YAweK2hYdfA9NI1VEpMiiwIFLSJ6%2B22aq5Rxh6FktuZoOapNU4%3D; "
    "WM_NIKE=9ca17ae2e6ffcda170e2e6eeade143f8ae9698c15490b08ba2d55f839a9b82c63982baababbc5db78cbab1cd2af0fea7c3b92a96b785a8b62183a88490e86b8eab82d9b77bf29de1a6f853bbaca4b0cb6a8c8b9ebbb241b49bfdabb165bc9eac85e45a94abbcb4f540f29f8789d7739bac8493f361f49ea5b8f97fb58d858df649b691febac47da795fe89dc70a69ff7afcc3b969bc0aeec63b5978aadd242f6f5fed3e47bf78eb889b54ea9acbbbbee45a3b082b6b737e2a3; "
    "WM_TID=faAKOqS1bFtBFRBQEROGeavmcU3b2DHu; JSESSIONID-WYYY=Zv%5CyHkFwwlUKAdh%2FVZmJPHil0kG6nRDnVwj%5ChhTs5Sgt3xXgv95SEltoJe35UdJ0IaVGnK8wY2elPddNhyfN2Ohpc4GHKl2KcfeIzjtpe0clYWUJ%2BbmyfoARF%5C48guilyzfb%2BvribE1%5CzxlKGq46aIuVDx6uW4%2Bq5xfjeeCQOmG6pFcV%3A1761397197645; "
    "_iuqxldmzr_=32; NTES_SESS=XPU8FmnsowZAB3FhApSJTLdS8MX2uOmiLyiw7r1izstVwsISwc4gjphtJVPv11kF2GfiBvVfojzUVYO.tTYmtHyuR40Govm9mprUG6FFdXQZGHiyGS2BEtlB.aZRa0iFIdPPFkkUDE_EvdwhEYid2SOo5eE3cv8q1RiC9CWn7VgZsoJ7jNcgpV_TefB44vkEVe_eqgvb4HSJfSBR2hEaWl7_3; "
    "S_INFO=1759041262|0|##|2911898435@qq.com; WEVNSM=1.0.0; gdxidpyhxdE=%2B7tsBZQR6IenEAivZzSyMphpK6BoYkMBIyU06dDedsZbb%2B0q4AuI%5C5Zl8Ti0Lo%2BZtmN2QYBv6N89hX15oxQDgPPa7pWYz7fyvzIGQ%5C4C%5C%2B6qfTN24OSCM%2Fj%5CJcXCZwQ8l0%5CqN6JI9kdEpv4t98n%2Fn7X1Rb%2FZfgyKxtnaQTgXY4aSUsvC%3A1760964140140; "
    "MUSIC_U=002E56DD064A6B385B5F6020B9C25306918FC64283622DB5B4D0C7FFEAF906FC3C114E6561EB9B60455076FD31707AF70E69994AC37113B3116478F68989ED77D4D7BD33E2A72EB80A809748E3695BBAF93544A553E7C7CA85AD6E16FA441DDC78580EB0D8CBD03C1656F474B006124240A678352C652D26E404BF18A90F7D772BEF080F252F97EB0C0AA33D22EDF542ABCE6CC25F37CA38DFE196948FBA5AB8C4124A9934BF25B04F42D9F0AC261BC2874D22258E74BAD6525B2DED6A3F361776813133769EBAE741EC5B0091DF8424CCCBCEFB695D2BA43EC761A6A85EA61E2AD035A0EC3A315351A8FB1E7BA56D6D2B1829831BA53F39490ACD9AED3D68882F29EED8204CBFFAB8B017456CF81D1305866B7DCB6897DADB61946363F96E21FC736F872F791E79B7A67CD6A67E73A6B8B0741CFEFD393D36CFF12F8627EF3D64DAB2A556091918A38BC896EAD79E5D08FD3F67A34A60D44DAFCD23F7B659B90117964496FA39C0BB2EDC2EB1785B1FED152BC7405316C7149F108F8FA13438247AB3A3B8BD7E11E6F69C6CC8F35D0CB3F2D5E55E1A11272981C11690879247D3; "
    "__csrf=e14279f12e2a2ecd5c471628acc1dd88; mcdev_cookie_id=njtmq_1760884764; timing_user_id=time_gKsbcBGUeT; "
    "NTES_P_UTID=Jcp0yN7E2JQjmXj6LrKHSOtCMJMHdPU0|1759041262; P_INFO=2911898435@qq.com|1759041262|0|x19_developer|00&99|hub&1752209068&x19_client#hub&422800#10#0#0|&0||2911898435@qq.com; "
    "__snaker__id=nkk8NhGmvx8TjgYp; WNMCID=saquay.1748005727710.01.0; _ntes_nnid=8f9dafc7d26f1bcecd2c38baac6c6897,1748005726212; _ntes_nuid=8f9dafc7d26f1bcecd2c38baac6c6897; "
    "NTES_CMT_USER_INFO=634944899%7C%E6%9C%89%E6%80%81%E5%BA%A6%E7%BD%91%E5%8F%8B0BS7S3%7Chttp%3A%2F%2Fcms-bucket.nosdn.127.net%2F2018%2F08%2F13%2F078ea9f65d954410b62a52ac773875a1.jpeg%7Cfalse%7CMjkxMTg5ODQzNUBxcS5jb20%3D; "
    "sDeviceId=YD-%2FCtbFrQxY4BBQxBAFAKDXaqmM1WFRU8u; NMTID=00Op8xYG56cBN46MUeQskLHYeowELcAAAGS_VBp9A"
)


def fetch_user_account(cookie_value: str) -> None:
    """调用需要登录的用户账户接口并打印结果。"""

    url = f"{BASE_URL}{LOGIN_REQUIRED_ENDPOINT}"
    req = request.Request(url)
    req.add_header("Cookie", cookie_value)
    req.add_header(
        "User-Agent",
        (
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
            "AppleWebKit/537.36 (KHTML, like Gecko) "
            "Chrome/126.0.0.0 Safari/537.36"
        ),
    )

    try:
        with request.urlopen(req, timeout=10) as resp:
            payload = resp.read().decode("utf-8", errors="replace")
            content_type = resp.headers.get("Content-Type", "")
            print(f"HTTP 状态码: {resp.status}")
            if "application/json" in content_type:
                try:
                    data = json.loads(payload)
                    print(json.dumps(data, indent=2, ensure_ascii=False))
                except json.JSONDecodeError:
                    print("响应标记为 JSON，但解析失败：")
                    print(payload)
            else:
                print("服务器返回了非 JSON 响应：")
                print(payload)
    except error.HTTPError as http_err:
        print(f"HTTP 错误 {http_err.code}: {http_err.reason}")
        try:
            details = http_err.read().decode("utf-8", errors="replace")
            if details:
                print(details)
        except Exception:
            pass
    except error.URLError as url_err:
        print(f"请求失败：{url_err.reason}")
    except Exception as exc:  # pragma: no cover - diagnostic path
        print(f"出现意外异常：{exc}")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="测试网络歌曲登录态接口")
    parser.add_argument(
        "--cookie",
        dest="cookie",
        help="直接传入完整的 Cookie 字符串（无需再交互输入）",
    )
    parser.add_argument(
        "--use-default",
        dest="use_default",
        action="store_true",
        help="使用脚本内置的默认 Cookie（仅用于调试）",
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()

    if args.use_default:
        cookie_header = DEFAULT_COOKIE
    elif args.cookie:
        cookie_header = args.cookie.strip().rstrip(";")
    else:
        print("请粘贴浏览器里复制的 Cookie（例如包含 MUSIC_U、__csrf 等字段）。")
        try:
            cookie_raw = input("Cookie> ")
        except EOFError:
            cookie_raw = ""
        cookie_header = cookie_raw.strip().rstrip(";")

        if not cookie_header:
            print("未输入 Cookie，自动使用脚本内置的默认 Cookie。", flush=True)
            cookie_header = DEFAULT_COOKIE

    if not cookie_header:
        print("未提供任何 Cookie。")
        return

    print("已读取 Cookie，准备请求接口。", flush=True)
    print(f"目标地址：{BASE_URL}{LOGIN_REQUIRED_ENDPOINT}", flush=True)
    print("正在向服务器发送请求，请稍候……", flush=True)

    fetch_user_account(cookie_header)


if __name__ == "__main__":
    main()
