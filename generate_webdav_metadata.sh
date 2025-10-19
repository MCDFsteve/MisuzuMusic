#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="${1:-.}"

if ! command -v ffmpeg >/dev/null 2>&1; then
  echo "[错误] 未找到 ffmpeg，请先安装。" >&2
  exit 1
fi

if ! command -v ffprobe >/dev/null 2>&1; then
  echo "[错误] 未找到 ffprobe，请先安装 (通常包含在 ffmpeg 中)。" >&2
  exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "[错误] 未找到 python3，请先安装。" >&2
  exit 1
fi

python3 - "${ROOT_DIR}" <<'PY'
import hashlib
import json
import os
import shlex
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(os.path.abspath(sys.argv[1] if len(sys.argv) > 1 else '.'))

SUPPORTED_EXTENSIONS = {
    '.mp3', '.flac', '.m4a', '.aac', '.wav', '.ogg',
    '.opus', '.wma', '.aiff', '.alac', '.dsf', '.ape', '.wv', '.mka'
}


def run_ffprobe(path: Path) -> dict:
    cmd = [
        'ffprobe', '-v', 'quiet', '-print_format', 'json',
        '-show_format', '-show_streams', str(path)
    ]
    try:
        result = subprocess.run(
            cmd,
            check=True,
            capture_output=True,
            text=True,
        )
    except subprocess.CalledProcessError as exc:
        raise RuntimeError(
            f"ffprobe 解析失败: {' '.join(shlex.quote(part) for part in cmd)}\n"
            f"stderr: {exc.stderr}"
        ) from exc

    try:
        return json.loads(result.stdout or '{}')
    except json.JSONDecodeError as exc:
        raise RuntimeError(f"ffprobe 输出 JSON 解析失败: {exc}") from exc


def extract_cover(source: Path, target: Path) -> bool:
    if target.exists():
        target.unlink()

    cmd = [
        'ffmpeg', '-y',
        '-i', str(source),
        '-map', '0:v:0',
        '-frames:v', '1',
        '-c:v', 'png',
        str(target),
    ]

    try:
        subprocess.run(cmd, check=True, capture_output=True)
        return target.exists()
    except subprocess.CalledProcessError:
        if target.exists():
            target.unlink()
        return False


def read_first_10kb_sha1(path: Path) -> str:
    with path.open('rb') as fp:
        data = fp.read(10240)
    return hashlib.sha1(data).hexdigest()


def normalize_tags(raw_tags: dict) -> dict:
    normalized = {}
    for key, value in (raw_tags or {}).items():
        if not isinstance(key, str):
            continue
        normalized[key.lower()] = value
    return normalized


def pick_tag(tags: dict, *candidates: str):
    for key in candidates:
        value = tags.get(key.lower())
        if value:
            return value
    return None


def parse_int_from_tag(value) -> int | None:
    if not value:
        return None
    if isinstance(value, (int, float)):
        return int(value)
    if not isinstance(value, str):
        return None
    cleaned = value.strip()
    for sep in ('/', '-', ';'):
        if sep in cleaned:
            cleaned = cleaned.split(sep, 1)[0].strip()
            break
    try:
        return int(cleaned)
    except ValueError:
        return None


def parse_year(value) -> int | None:
    if not value:
        return None
    if isinstance(value, (int, float)):
        return int(value)
    if not isinstance(value, str):
        return None
    digits = ''.join(ch for ch in value if ch.isdigit())
    if len(digits) >= 4:
        try:
            return int(digits[:4])
        except ValueError:
            return None
    return None


def build_metadata(source: Path, probe: dict, has_cover: bool) -> dict:
    tags = normalize_tags(probe.get('format', {}).get('tags') or {})
    streams = probe.get('streams', []) or []
    audio_stream = next(
        (stream for stream in streams if stream.get('codec_type') == 'audio'),
        {},
    )

    duration_raw = probe.get('format', {}).get('duration')
    duration_ms = None
    if duration_raw:
        try:
            duration_ms = int(float(duration_raw) * 1000)
        except (ValueError, TypeError):
            duration_ms = None

    bit_rate_raw = probe.get('format', {}).get('bit_rate')
    bit_rate = None
    if bit_rate_raw:
        try:
            bit_rate = int(bit_rate_raw)
        except (ValueError, TypeError):
            bit_rate = None

    sample_rate_raw = audio_stream.get('sample_rate')
    sample_rate = None
    if sample_rate_raw:
        try:
            sample_rate = int(sample_rate_raw)
        except (ValueError, TypeError):
            sample_rate = None

    channels = audio_stream.get('channels')
    if isinstance(channels, str) and channels.isdigit():
        channels = int(channels)
    elif not isinstance(channels, int):
        channels = None

    channel_layout = audio_stream.get('channel_layout')
    codec_name = audio_stream.get('codec_name')

    title = pick_tag(tags, 'title') or source.stem
    artist = pick_tag(tags, 'artist', 'album_artist', 'author') or 'Unknown Artist'
    album = pick_tag(tags, 'album') or 'Unknown Album'
    album_artist = pick_tag(tags, 'album_artist', 'albumartist')
    genre = pick_tag(tags, 'genre')
    year = parse_year(pick_tag(tags, 'date', 'year'))
    track_number = parse_int_from_tag(pick_tag(tags, 'track', 'tracknumber', 'track_number'))
    disc_number = parse_int_from_tag(pick_tag(tags, 'disc', 'discnumber', 'disc_number'))

    stats = source.stat()
    modified = datetime.fromtimestamp(stats.st_mtime, tz=timezone.utc).isoformat()

    metadata = {
        'source_file': source.name,
        'title': title,
        'artist': artist,
        'album': album,
        'album_artist': album_artist,
        'genre': genre,
        'year': year,
        'track_number': track_number,
        'disc_number': disc_number,
        'duration_ms': duration_ms,
        'bit_rate': bit_rate,
        'sample_rate': sample_rate,
        'channels': channels,
        'channel_layout': channel_layout,
        'codec': codec_name,
        'file_size': stats.st_size,
        'modified_utc': modified,
        'hash_sha1_first_10kb': read_first_10kb_sha1(source),
        'has_cover': has_cover,
        'cover_file': f"{source.stem}.png" if has_cover else None,
        'tags': {k: v for k, v in sorted(tags.items())},
    }

    return metadata


def main(root: Path):
    audio_files = []
    for dirpath, _, filenames in os.walk(root):
        for filename in filenames:
            ext = os.path.splitext(filename)[1].lower()
            if ext in SUPPORTED_EXTENSIONS:
                audio_files.append(Path(dirpath) / filename)

    if not audio_files:
        print(f"[信息] 在 {root} 未找到音频文件。")
        return

    audio_files.sort()

    for index, audio_path in enumerate(audio_files, start=1):
        relative = audio_path.relative_to(root)
        print(f"[处理 {index}/{len(audio_files)}] {relative}")

        probe = run_ffprobe(audio_path)

        cover_path = audio_path.with_suffix('.png')
        has_cover = extract_cover(audio_path, cover_path)

        metadata = build_metadata(audio_path, probe, has_cover)

        json_path = audio_path.with_suffix('.json')
        with json_path.open('w', encoding='utf-8') as fp:
            json.dump(metadata, fp, ensure_ascii=False, indent=2)

    print('[完成] 元数据和封面导出完成。')


if __name__ == '__main__':
    main(ROOT)
PY
