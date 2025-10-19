#!/usr/bin/env python3
"""Misuzu Music WebDAV media service.

持续运行在服务器侧：
1. 扫描指定根目录的音频文件，使用 ffprobe/ffmpeg 生成元数据 JSON 与封面 PNG；
2. 将所有元数据与封面合并为单个二进制包（library.bundle）；
3. 监听播放日志目录（playlogs），把客户端上传的播放日志二进制合并到主包的统计信息中；
4. 处理完成后自动删除播放日志文件。

运行示例：
    python3 tools/webdav_media_service.py /data/disk1/music

必备依赖：ffmpeg/ffprobe、python3 标准库。
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import shutil
import struct
import subprocess
import sys
import time
from dataclasses import dataclass, field
from datetime import datetime, timezone
from pathlib import Path
from typing import Dict, Iterable, List, Optional

AUDIO_EXTENSIONS = {
    '.mp3', '.flac', '.m4a', '.aac', '.wav', '.ogg', '.opus', '.wma',
    '.aiff', '.alac', '.dsf', '.ape', '.wv', '.mka'
}

MAGIC_METADATA = b'MMDB'
MAGIC_PLAYLOG = b'MMLG'
BUNDLE_VERSION = 1
PLAYLOG_VERSION = 1

METADATA_DIRNAME = '.misuzu'
METADATA_BUNDLE_NAME = 'library.bundle'
PLAYLOG_DIRNAME = 'playlogs'


class MediaServiceError(RuntimeError):
    pass


def debug(msg: str) -> None:
    timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
    print(f'[{timestamp}] {msg}', flush=True)


def run_ffprobe(audio_path: Path) -> dict:
    cmd = [
        'ffprobe', '-v', 'quiet', '-print_format', 'json',
        '-show_format', '-show_streams', str(audio_path),
    ]
    try:
        result = subprocess.run(
            cmd,
            check=True,
            capture_output=True,
            text=True,
        )
    except subprocess.CalledProcessError as exc:  # pragma: no cover - runtime tool
        raise MediaServiceError(
            f"ffprobe failed for {audio_path}: {exc.stderr}"
        ) from exc

    try:
        return json.loads(result.stdout or '{}')
    except json.JSONDecodeError as exc:
        raise MediaServiceError(f'ffprobe invalid JSON for {audio_path}: {exc}') from exc


def extract_cover_images(
    audio_path: Path,
    fullsize_webp: Path,
    thumbnail_webp: Path,
    existing_png: Optional[Path] = None,
) -> bool:
    temp_png = audio_path.with_suffix('.__cover_tmp.png')
    for target in (fullsize_webp, thumbnail_webp, temp_png):
        if target.exists():
            target.unlink()

    png_source = existing_png if existing_png and existing_png.exists() else None
    if png_source is None:
        # try locate any png in same directory
        for candidate in audio_path.parent.glob('*.png'):
            if candidate.exists():
                png_source = candidate
                break

    if png_source is None:
        extract_cmd = [
            'ffmpeg', '-v', 'error', '-y',
            '-i', str(audio_path),
            '-map', '0:v:0',
            '-frames:v', '1',
            str(temp_png),
        ]

        try:
            subprocess.run(extract_cmd, check=True, capture_output=True)
            png_source = temp_png if temp_png.exists() else None
        except subprocess.CalledProcessError:  # pragma: no cover - runtime tool
            if temp_png.exists():
                temp_png.unlink()
            return False

    if png_source is None:
        return False

    convert_full_cmd = [
        'ffmpeg', '-v', 'error', '-y',
        '-i', str(png_source),
        '-quality', '94',
        '-compression_level', '4',
        str(fullsize_webp),
    ]

    try:
        subprocess.run(convert_full_cmd, check=True, capture_output=True)
    except subprocess.CalledProcessError as exc:  # pragma: no cover
        debug(f'  ⚠️ WebP 转换失败 (full) -> {exc.stderr.strip()}')
        for target in (temp_png, fullsize_webp, thumbnail_webp):
            target.unlink(missing_ok=True)
        return False

    convert_thumb_cmd = [
        'ffmpeg', '-v', 'error', '-y',
        '-i', str(png_source),
        '-vf', 'scale=160:-1:flags=lanczos',
        '-quality', '85',
        '-compression_level', '4',
        str(thumbnail_webp),
    ]

    try:
        subprocess.run(convert_thumb_cmd, check=True, capture_output=True)
    except subprocess.CalledProcessError as exc:  # pragma: no cover
        debug(f'  ⚠️ 缩略图转换失败 -> {exc.stderr.strip()}')
        for target in (temp_png, thumbnail_webp):
            target.unlink(missing_ok=True)
        fullsize_webp.unlink(missing_ok=True)
        return False
    finally:
        if png_source is temp_png:
            temp_png.unlink(missing_ok=True)

    return fullsize_webp.exists() and thumbnail_webp.exists()


def compute_sha1_first_chunk(audio_path: Path, chunk_size: int = 10240) -> str:
    h = hashlib.sha1()
    with audio_path.open('rb') as fp:
        data = fp.read(chunk_size)
        h.update(data)
    return h.hexdigest()


def normalize_tags(raw_tags: Optional[dict]) -> Dict[str, str]:
    tags: Dict[str, str] = {}
    if not raw_tags:
        return tags
    for key, value in raw_tags.items():
        if isinstance(key, str):
            tags[key.lower()] = value
    return tags


def pick_tag(tags: Dict[str, str], *candidates: str) -> Optional[str]:
    for key in candidates:
        value = tags.get(key.lower())
        if value:
            return value
    return None


def parse_int(value) -> Optional[int]:
    if value is None:
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


def parse_year(value) -> Optional[int]:
    if value is None:
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


@dataclass
class TrackStat:
    play_count: int = 0
    last_play_timestamp_ms: int = 0


@dataclass
class TrackMetadata:
    track_id: str
    relative_path: str
    metadata_json: dict
    artwork_path: Optional[Path]
    stats: TrackStat = field(default_factory=TrackStat)


class MediaLibrary:
    def __init__(self, root: Path):
        self.root = root
        self.meta_dir = root / METADATA_DIRNAME
        self.bundle_path = self.meta_dir / METADATA_BUNDLE_NAME
        self.playlog_dir = self.meta_dir / PLAYLOG_DIRNAME
        self.meta_dir.mkdir(exist_ok=True)
        self.playlog_dir.mkdir(exist_ok=True)
        self.tracks: Dict[str, TrackMetadata] = {}
        self._load_existing_bundle()

    # ------------------------------------------------------------------
    # Bundle load/save
    # ------------------------------------------------------------------
    def _load_existing_bundle(self) -> None:
        if not self.bundle_path.exists():
            debug('Bundle not found, starting with empty library.')
            return

        data = self.bundle_path.read_bytes()
        try:
            entries = self._parse_bundle(data)
        except Exception as exc:  # pragma: no cover - tool runtime
            debug(f'Failed to parse existing bundle: {exc}. Ignoring.')
            return

        for entry in entries:
            self.tracks[entry.track_id] = entry
        debug(f'Loaded {len(self.tracks)} entries from existing bundle.')

    @staticmethod
    def _parse_bundle(data: bytes) -> List[TrackMetadata]:
        mv = memoryview(data)
        offset = 0

        def require(size: int) -> memoryview:
            nonlocal offset
            if offset + size > len(mv):
                raise MediaServiceError('Bundle truncated')
            segment = mv[offset:offset + size]
            offset += size
            return segment

        header = require(4 + 2 + 2 + 8 + 4)
        magic, version, _flags, timestamp_ms, count = struct.unpack('<4sHHQI', header)
        if magic != MAGIC_METADATA:
            raise MediaServiceError('Invalid metadata bundle magic')
        if version != BUNDLE_VERSION:
            raise MediaServiceError(f'Unsupported bundle version: {version}')
        debug(
            f'Existing bundle built at {datetime.fromtimestamp(timestamp_ms / 1000, tz=timezone.utc)} '
            f'with {count} entries.'
        )

        entries: List[TrackMetadata] = []
        for _ in range(count):
            key_len = struct.unpack('<H', require(2))[0]
            key = bytes(require(key_len)).decode('utf-8')

            hash_len = struct.unpack('<B', require(1))[0]
            track_id = bytes(require(hash_len)).decode('utf-8')

            metadata_len = struct.unpack('<I', require(4))[0]
            metadata_bytes = bytes(require(metadata_len))
            metadata_json = json.loads(metadata_bytes.decode('utf-8'))

            artwork_len = struct.unpack('<I', require(4))[0]
            if artwork_len:
                _ = require(artwork_len)  # discard artwork payload when loading existing stats

            play_count = struct.unpack('<I', require(4))[0]
            last_play_ts = struct.unpack('<Q', require(8))[0]

            stats = TrackStat(play_count=play_count, last_play_timestamp_ms=last_play_ts)
            entry = TrackMetadata(
                track_id=track_id,
                relative_path=metadata_json.get('relative_path', key),
                metadata_json=metadata_json,
                artwork_path=None,
                stats=stats,
            )
            entries.append(entry)

        if offset != len(mv):  # pragma: no cover - runtime safety
            debug('Warning: extra bytes detected at end of bundle.')
        return entries

    def save_bundle(self) -> None:
        entries = list(self.tracks.values())
        entries.sort(key=lambda e: e.track_id)

        tmp_path = self.bundle_path.with_suffix('.tmp')
        with tmp_path.open('wb') as fp:
            fp.write(
                struct.pack(
                    '<4sHHQI',
                    MAGIC_METADATA,
                    BUNDLE_VERSION,
                    0,
                    int(time.time() * 1000),
                    len(entries),
                ),
            )

            for entry in entries:
                metadata_bytes = json.dumps(
                    entry.metadata_json,
                    ensure_ascii=False,
                ).encode('utf-8')
                artwork_bytes = (
                    entry.artwork_path.read_bytes() if entry.artwork_path else b''
                )

                key_bytes = entry.metadata_json.get(
                    'relative_path',
                    entry.relative_path,
                ).encode('utf-8')
                track_id_bytes = entry.track_id.encode('utf-8')

                fp.write(struct.pack('<H', len(key_bytes)))
                fp.write(key_bytes)
                fp.write(struct.pack('<B', len(track_id_bytes)))
                fp.write(track_id_bytes)
                fp.write(struct.pack('<I', len(metadata_bytes)))
                fp.write(metadata_bytes)
                fp.write(struct.pack('<I', len(artwork_bytes)))
                fp.write(artwork_bytes)
                fp.write(struct.pack('<I', entry.stats.play_count))
                fp.write(struct.pack('<Q', entry.stats.last_play_timestamp_ms))

        tmp_path.replace(self.bundle_path)
        debug(f'Bundle updated: {self.bundle_path} ({len(entries)} entries).')

    # ------------------------------------------------------------------
    # Metadata generation
    # ------------------------------------------------------------------
    def ensure_metadata(self) -> bool:
        """Return True if any metadata/cover was generated or updated."""
        changed = False
        for audio_path in self.iter_audio_files():
            json_path = audio_path.with_suffix('.json')
            fullsize_webp = audio_path.with_suffix('.webp')
            thumb_webp = audio_path.with_suffix('.thumb.webp')

            regenerate = False
            if json_path.exists():
                try:
                    regenerate = json_path.stat().st_mtime < audio_path.stat().st_mtime
                except OSError:
                    regenerate = False
            else:
                regenerate = True

            if not fullsize_webp.exists() or not thumb_webp.exists():
                regenerate = True

            if not regenerate:
                continue

            action = '更新' if json_path.exists() else '生成'
            debug(f'{action}元数据 -> {audio_path.relative_to(self.root)}')

            legacy_png = audio_path.with_suffix('.png')
            if not extract_cover_images(
                audio_path,
                fullsize_webp,
                thumb_webp,
                existing_png=legacy_png if legacy_png.exists() else None,
            ):
                debug('  ⚠️ 封面提取失败，跳过')
                continue

            metadata = self._extract_metadata(audio_path)
            metadata['has_cover'] = True
            metadata['cover_file'] = '/' + str(fullsize_webp.relative_to(self.root)).replace('\\', '/')
            metadata['thumbnail_file'] = '/' + str(thumb_webp.relative_to(self.root)).replace('\\', '/')

            json_path.write_text(
                json.dumps(metadata, ensure_ascii=False, indent=2),
                encoding='utf-8',
            )

            legacy_png = audio_path.with_suffix('.png')
            if legacy_png.exists():
                legacy_png.unlink()

            changed = True
        return changed

    def _extract_metadata(self, audio_path: Path) -> dict:
        probe = run_ffprobe(audio_path)
        tags = normalize_tags(probe.get('format', {}).get('tags'))
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

        bit_rate = parse_int(probe.get('format', {}).get('bit_rate'))
        sample_rate = parse_int(audio_stream.get('sample_rate'))
        channels = parse_int(audio_stream.get('channels'))
        channel_layout = audio_stream.get('channel_layout')
        codec_name = audio_stream.get('codec_name')

        title = pick_tag(tags, 'title') or audio_path.stem
        artist = pick_tag(tags, 'artist', 'album_artist', 'author') or 'Unknown Artist'
        album = pick_tag(tags, 'album') or 'Unknown Album'
        album_artist = pick_tag(tags, 'album_artist', 'albumartist')
        genre = pick_tag(tags, 'genre')
        year = parse_year(pick_tag(tags, 'date', 'year'))
        track_number = parse_int(pick_tag(tags, 'track', 'tracknumber', 'track_number'))
        disc_number = parse_int(pick_tag(tags, 'disc', 'discnumber', 'disc_number'))

        stats = audio_path.stat()
        fingerprint = compute_sha1_first_chunk(audio_path)

        metadata = {
            'source_file': audio_path.name,
            'relative_path': '/' + str(audio_path.relative_to(self.root)).replace('\\', '/'),
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
            'modified_utc': datetime.fromtimestamp(stats.st_mtime, tz=timezone.utc).isoformat(),
            'hash_sha1_first_10kb': fingerprint,
        }
        return metadata

    def iter_audio_files(self) -> Iterable[Path]:
        for path in self.root.rglob('*'):
            if path.suffix.lower() in AUDIO_EXTENSIONS and path.is_file():
                # 跳过 .misuzu 目录内部的音频
                try:
                    path.relative_to(self.meta_dir)
                    continue
                except ValueError:
                    yield path

    def rebuild_bundle_from_json(self) -> bool:
        """Rebuild in-memory metadata from JSON/PNG. Return True if changed."""
        changed = False
        for json_path in sorted(self.root.rglob('*.json')):
            try:
                json_path.relative_to(self.meta_dir)
                continue  # Skip files inside .misuzu
            except ValueError:
                pass

            audio_path = json_path.with_suffix('')
            if json_path.stem == 'library':
                continue
            if json_path.suffix.lower() != '.json':
                continue
            with json_path.open('r', encoding='utf-8') as fp:
                metadata_json = json.load(fp)

            track_id = metadata_json.get('hash_sha1_first_10kb')
            if not track_id:
                debug(f'⚠️ Metadata missing hash: {json_path}')
                continue

            relative_path = metadata_json.get('relative_path')
            if not relative_path:
                # derive from json path
                relative_path = '/' + str(audio_path.relative_to(self.root)).replace('\\', '/')
                metadata_json['relative_path'] = relative_path

            thumbnail_rel = metadata_json.get('thumbnail_file')
            artwork_path = None
            if thumbnail_rel:
                candidate = self.root / thumbnail_rel.lstrip('/')
                if candidate.exists():
                    artwork_path = candidate
            if artwork_path is None:
                fallback_thumb = audio_path.with_suffix('.thumb.webp')
                if fallback_thumb.exists():
                    artwork_path = fallback_thumb
                    metadata_json['thumbnail_file'] = '/' + str(
                        fallback_thumb.relative_to(self.root)
                    ).replace('\\', '/')

            if 'cover_file' not in metadata_json:
                full_webp = audio_path.with_suffix('.webp')
                if full_webp.exists():
                    metadata_json['cover_file'] = '/' + str(
                        full_webp.relative_to(self.root)
                    ).replace('\\', '/')

            existing = self.tracks.get(track_id)
            if existing:
                existing.metadata_json = metadata_json
                existing.relative_path = relative_path
                existing.artwork_path = artwork_path
            else:
                self.tracks[track_id] = TrackMetadata(
                    track_id=track_id,
                    relative_path=relative_path,
                    metadata_json=metadata_json,
                    artwork_path=artwork_path,
                )
                changed = True
        return changed

    # ------------------------------------------------------------------
    # Play log processing
    # ------------------------------------------------------------------
    def process_play_logs(self) -> bool:
        changed = False
        log_files = sorted(self.playlog_dir.glob('playlog_*.bin'))
        if not log_files:
            return False

        for log_path in log_files:
            try:
                entries = self._parse_playlog(log_path.read_bytes())
            except Exception as exc:  # pragma: no cover - runtime tool
                debug(f'Failed to parse playlog {log_path.name}: {exc}, deleting file.')
                log_path.unlink(missing_ok=True)
                continue

            for timestamp_ms, track_id in entries:
                track = self.tracks.get(track_id)
                if not track:
                    debug(f'⚠️ Playlog entry for unknown track {track_id}, skipping.')
                    continue
                track.stats.play_count += 1
                if timestamp_ms > track.stats.last_play_timestamp_ms:
                    track.stats.last_play_timestamp_ms = timestamp_ms
                changed = True

            log_path.unlink(missing_ok=True)
            debug(f'Processed playlog {log_path.name} ({len(entries)} entries).')

        return changed

    @staticmethod
    def _parse_playlog(data: bytes) -> List[tuple[int, str]]:
        mv = memoryview(data)
        offset = 0

        def require(size: int) -> memoryview:
            nonlocal offset
            if offset + size > len(mv):
                raise MediaServiceError('Playlog truncated')
            segment = mv[offset:offset + size]
            offset += size
            return segment

        header = require(4 + 2 + 4)
        magic, version, count = struct.unpack('<4sHI', header)
        if magic != MAGIC_PLAYLOG:
            raise MediaServiceError('Invalid playlog magic')
        if version != PLAYLOG_VERSION:
            raise MediaServiceError(f'Unsupported playlog version {version}')

        entries: List[tuple[int, str]] = []
        for _ in range(count):
            timestamp_ms = struct.unpack('<Q', require(8))[0]
            hash_len = struct.unpack('<B', require(1))[0]
            track_id = bytes(require(hash_len)).decode('utf-8')
            entries.append((timestamp_ms, track_id))

        return entries


def main() -> None:
    parser = argparse.ArgumentParser(description='Misuzu Music WebDAV media service')
    parser.add_argument('root', type=Path, help='音频根目录（WebDAV 挂载点）')
    parser.add_argument('--interval', type=int, default=60, help='循环间隔秒数（默认 60）')
    args = parser.parse_args()

    root = args.root.resolve()
    if not root.exists() or not root.is_dir():
        raise SystemExit(f'根目录不存在: {root}')

    for binary in ('ffmpeg', 'ffprobe'):
        if not shutil.which(binary):
            raise SystemExit(f'Missing dependency: {binary}')

    service = MediaLibrary(root)
    debug(f'Service started. Root={root}')

    while True:
        changed = False
        try:
            if service.ensure_metadata():
                debug('Metadata generation finished, rebuilding bundle...')
                changed = True

            if service.rebuild_bundle_from_json():
                debug('Metadata map updated from JSON.')
                changed = True

            if service.process_play_logs():
                debug('Playlog merge completed.')
                changed = True

            if changed:
                service.save_bundle()
        except Exception as exc:  # pragma: no cover - runtime loop safety
            debug(f'Unexpected error: {exc}')

        time.sleep(max(args.interval, 5))


if __name__ == '__main__':
    try:
        import shutil  # noqa: WPS433 - imported late for dependency check
        main()
    except KeyboardInterrupt:  # pragma: no cover
        debug('Service interrupted by user.')
    except MediaServiceError as exc:
        debug(f'Fatal: {exc}')
        sys.exit(1)
