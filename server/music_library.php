<?php
declare(strict_types=1);

/**
 * Misuzu 云音乐库服务
 *
 * 功能：
 * - action=list           返回音乐及元数据 JSON 列表
 * - action=stream         流式输出音频文件（支持 Range）
 * - action=cover          输出封面 webp
 * - action=thumbnail      输出缩略图 webp
 * - action=upload         上传音频并生成 json / 封面
 * - 无 action + 未提供 code 时，返回 Fluent UI 风格的网页
 *
 * 注意：
 * 1. MUSIC_ROOT 必须在 PHP open_basedir 允许范围内。
 * 2. 上传 / 元数据依赖 ffmpeg 与 ffprobe。
 */

const MUSIC_ROOT       = __DIR__ . '/music_library_data';
const SECRET_CODE      = 'irigas';
const AUDIO_EXTENSIONS = ['mp3','flac','wav','m4a','aac','ogg','opus','wv','ape'];
const MAX_CHUNK_BYTES  = 8_388_608; // 8 MB

/* -------------------------------------------------------------------------- */
/* 入口控制                                                                    */
/* -------------------------------------------------------------------------- */

if (!is_dir(MUSIC_ROOT)) {
    respondJson(
        500,
        '服务器未配置音乐目录: ' . MUSIC_ROOT,
        ['hint' => '请确认 MUSIC_ROOT 在当前环境可读，且已加入 open_basedir 白名单。']
    );
}

$method = strtoupper($_SERVER['REQUEST_METHOD'] ?? 'GET');
$action = $_REQUEST['action'] ?? null;
$code   = $_REQUEST['code'] ?? '';
$accept = $_SERVER['HTTP_ACCEPT'] ?? '';

$wantHtml = $method === 'GET'
    && $action === null
    && (empty($code) || strcasecmp($code, SECRET_CODE) !== 0)
    && (str_contains($accept, 'text/html') || !str_contains($accept, 'application/json'));

if ($wantHtml) {
    serveHtmlUi();
    exit;
}

switch ($action) {
    case 'list':
        requireCode($code);
        handleList();
        break;
    case 'stream':
        requireCode($code);
        handleStream();
        break;
    case 'cover':
        requireCode($code);
        handleAsset(false);
        break;
    case 'thumbnail':
        requireCode($code);
        handleAsset(true);
        break;
    case 'upload':
        requireCode($code);
        handleUpload();
        break;
    default:
        respondJson(400, '未知操作');
        break;
}

/* -------------------------------------------------------------------------- */
/* 业务逻辑                                                                    */
/* -------------------------------------------------------------------------- */

function requireCode(string $provided): void
{
    if (strcasecmp($provided, SECRET_CODE) !== 0) {
        respondJson(403, '缺少或非法的神秘代码');
    }
}

function handleList(): void
{
    try {
        $directory = new RecursiveDirectoryIterator(
            MUSIC_ROOT,
            FilesystemIterator::SKIP_DOTS | FilesystemIterator::CURRENT_AS_FILEINFO
        );
    } catch (UnexpectedValueException $e) {
        respondJson(500, '无法读取音乐目录', ['error' => $e->getMessage()]);
    }

    $iterator = new RecursiveIteratorIterator(
        $directory,
        RecursiveIteratorIterator::LEAVES_ONLY,
        RecursiveIteratorIterator::CATCH_GET_CHILD
    );

    $tracks = [];
    foreach ($iterator as $info) {
        try {
            if (!$info instanceof SplFileInfo || !$info->isFile() || !$info->isReadable()) {
                continue;
            }
        } catch (UnexpectedValueException $e) {
            continue;
        }

        $ext = strtolower($info->getExtension());
        if (!in_array($ext, AUDIO_EXTENSIONS, true)) {
            continue;
        }

        $metadata = loadTrackMetadata($info->getPathname());
        if ($metadata === null) {
            continue;
        }

        $tracks[] = [
            'metadata'       => $metadata,
            'relative_path'  => relativePath($info->getPathname()),
            'cover_path'     => $metadata['cover_file'] ?? null,
            'thumbnail_path' => $metadata['thumbnail_file'] ?? null,
        ];
    }

    usort(
        $tracks,
        static fn($a, $b) => strcmp(
            $a['metadata']['title'] ?? $a['relative_path'],
            $b['metadata']['title'] ?? $b['relative_path']
        )
    );

    respondJson(200, 'ok', ['tracks' => $tracks]);
}

function handleStream(): void
{
    $relative = $_GET['path'] ?? '';
    if ($relative === '') {
        respondJson(400, '缺少 path 参数');
        return;
    }

    $audioPath = absolutePath($relative);
    if ($audioPath === null || !is_file($audioPath)) {
        respondJson(404, '未找到音频文件');
        return;
    }

    $mime     = mime_content_type($audioPath) ?: 'application/octet-stream';
    $filesize = filesize($audioPath);

    header('Content-Type: ' . $mime);
    header('Accept-Ranges', 'bytes');

    $start = 0;
    $end   = $filesize - 1;

    if (isset($_SERVER['HTTP_RANGE']) && preg_match('/bytes=([0-9]*)-([0-9]*)/', $_SERVER['HTTP_RANGE'], $matches)) {
        if ($matches[1] !== '') {
            $start = (int)$matches[1];
        }
        if ($matches[2] !== '') {
            $end = (int)$matches[2];
        }
        if ($end >= $filesize) {
            $end = $filesize - 1;
        }
        if ($start > $end || $start < 0) {
            respondJson(416, '非法的 Range 请求');
            return;
        }
        http_response_code(206);
        header(sprintf('Content-Range: bytes %d-%d/%d', $start, $end, $filesize));
    }

    $length = $end - $start + 1;
    header('Content-Length: ' . $length);

    $fp = fopen($audioPath, 'rb');
    if ($fp === false) {
        respondJson(500, '无法读取音频');
        return;
    }

    ignore_user_abort(true);
    set_time_limit(0);

    fseek($fp, $start);
    $remaining = $length;
    while ($remaining > 0 && !feof($fp)) {
        $chunk  = (int)min(MAX_CHUNK_BYTES, $remaining);
        $buffer = fread($fp, $chunk);
        if ($buffer === false) {
            break;
        }
        echo $buffer;
        $remaining -= strlen($buffer);
        if (connection_status() !== CONNECTION_NORMAL) {
            break;
        }
    }
    fclose($fp);
}

function handleAsset(bool $isThumb = false): void
{
    $relative = $_GET['path'] ?? '';
    if ($relative === '') {
        respondJson(400, '缺少 path 参数');
        return;
    }

    $assetPath = absolutePath($relative);
    if ($assetPath === null || !is_file($assetPath)) {
        respondJson(404, '未找到资源');
        return;
    }

    $mime = mime_content_type($assetPath) ?: 'application/octet-stream';
    header('Content-Type: ' . $mime);
    header('Content-Length: ' . filesize($assetPath));
    readfile($assetPath);
}

function handleUpload(): void
{
    if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
        respondJson(405, '仅支持 POST 上传');
        return;
    }

    if (empty($_FILES['music_file']['tmp_name'])) {
        respondJson(400, '未选择文件');
        return;
    }

    $original  = $_FILES['music_file']['name'] ?? 'upload';
    $sanitized = sanitizeFilename($original);
    if ($sanitized === '') {
        respondJson(400, '非法文件名');
        return;
    }

    $ext = strtolower(pathinfo($sanitized, PATHINFO_EXTENSION));
    if (!in_array($ext, AUDIO_EXTENSIONS, true)) {
        respondJson(400, '不支持的音频格式');
        return;
    }

    $target = MUSIC_ROOT . DIRECTORY_SEPARATOR . $sanitized;
    $count  = 1;
    while (file_exists($target)) {
        $target = sprintf(
            '%s/%s_%d.%s',
            MUSIC_ROOT,
            pathinfo($sanitized, PATHINFO_FILENAME),
            $count++,
            $ext
        );
    }

    if (!move_uploaded_file($_FILES['music_file']['tmp_name'], $target)) {
        respondJson(500, '保存上传文件失败');
        return;
    }

    $metadata = loadTrackMetadata($target, true);
    if ($metadata === null) {
        respondJson(500, '无法生成元数据');
        return;
    }

    respondJson(200, '上传成功', [
        'track' => [
            'metadata'       => $metadata,
            'relative_path'  => relativePath($target),
            'cover_path'     => $metadata['cover_file'] ?? null,
            'thumbnail_path' => $metadata['thumbnail_file'] ?? null,
        ],
    ]);
}

/* -------------------------------------------------------------------------- */
/* 工具函数                                                                    */
/* -------------------------------------------------------------------------- */

function respondJson(int $status, string $message, array $payload = []): void
{
    http_response_code($status);
    header('Content-Type: application/json; charset=utf-8');
    $success = $status >= 200 && $status < 300;
    echo json_encode([
        'success' => $success,
        'message' => $message,
    ] + $payload, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
    exit;
}

function absolutePath(string $relative): ?string
{
    $relative  = str_replace(chr(92), '/', $relative);
    $relative  = ltrim($relative, '/');
    $candidate = MUSIC_ROOT . '/' . $relative;

    $resolved = realpath($candidate);
    if ($resolved === false) {
        $base     = dirname($candidate);
        $resolved = realpath($base);
        if ($resolved === false) {
            return null;
        }
        $resolved .= '/' . basename($candidate);
    }

    // 防目录爬升
    if (!str_starts_with($resolved, MUSIC_ROOT)) {
        return null;
    }

    return $resolved;
}

function relativePath(string $absolute): string
{
    $absolute = str_replace(chr(92), '/', $absolute);
    $root     = str_replace(chr(92), '/', MUSIC_ROOT);
    if (!str_starts_with($absolute, $root)) {
        return '';
    }
    $relative = substr($absolute, strlen($root));
    if ($relative === false) {
        $relative = '';
    }
    return '/' . ltrim($relative, '/');
}

function sanitizeFilename(string $name): string
{
    $base = pathinfo($name, PATHINFO_FILENAME);
    $ext  = pathinfo($name, PATHINFO_EXTENSION);

    $safeBase = preg_replace('/[^A-Za-z0-9 _-]+/', '_', $base) ?? '';
    $safeBase = trim($safeBase, ' _');
    if ($safeBase === '') {
        $safeBase = 'track_' . date('Ymd_His');
    }

    $safeExt = preg_replace('/[^A-Za-Z0-9]+/', '', $ext) ?? '';
    return $safeBase . ($safeExt === '' ? '' : '.' . strtolower($safeExt));
}

function libraryStats(): array
{
    $stats = [
        'path' => MUSIC_ROOT,
        'audio_count' => 0,
        'total_files' => 0,
        'audio_bytes' => 0,
    ];

    if (!is_dir(MUSIC_ROOT)) {
        return $stats;
    }

    try {
        $directory = new RecursiveDirectoryIterator(MUSIC_ROOT, FilesystemIterator::SKIP_DOTS);
        $directory->setFlags(
            FilesystemIterator::SKIP_DOTS
            | FilesystemIterator::CURRENT_AS_FILEINFO
            | FilesystemIterator::FOLLOW_SYMLINKS
        );
    } catch (UnexpectedValueException) {
        return $stats;
    }

    $iterator = new RecursiveIteratorIterator(
        $directory,
        RecursiveIteratorIterator::LEAVES_ONLY,
        RecursiveIteratorIterator::CATCH_GET_CHILD
    );

    foreach ($iterator as $info) {
        if (!$info->isFile()) {
            continue;
        }
        $stats['total_files']++;
        if (in_array(strtolower($info->getExtension()), AUDIO_EXTENSIONS, true)) {
            $stats['audio_count']++;
            $stats['audio_bytes'] += $info->getSize();
        }
    }

    return $stats;
}

function listAudioRelativePaths(int $limit = 200): array
{
    if (!is_dir(MUSIC_ROOT)) {
        return [];
    }

    $paths = [];
    try {
        $directory = new RecursiveDirectoryIterator(MUSIC_ROOT, FilesystemIterator::SKIP_DOTS);
        $directory->setFlags(
            FilesystemIterator::SKIP_DOTS
            | FilesystemIterator::CURRENT_AS_FILEINFO
            | FilesystemIterator::FOLLOW_SYMLINKS
        );
    } catch (UnexpectedValueException) {
        return [];
    }

    $iterator = new RecursiveIteratorIterator(
        $directory,
        RecursiveIteratorIterator::LEAVES_ONLY,
        RecursiveIteratorIterator::CATCH_GET_CHILD
    );

    foreach ($iterator as $info) {
        if (!$info->isFile()) {
            continue;
        }
        $ext = strtolower($info->getExtension());
        if (!in_array($ext, AUDIO_EXTENSIONS, true)) {
            continue;
        }
        $paths[] = relativePath($info->getPathname());
        if ($limit > 0 && count($paths) >= $limit) {
            break;
        }
    }

    sort($paths, SORT_NATURAL | SORT_FLAG_CASE);

    return $paths;
}


function formatBytes(int $bytes): string
{
    if ($bytes <= 0) {
        return '0 B';
    }

    $units = ['B', 'KB', 'MB', 'GB', 'TB', 'PB'];
    $value = (float)$bytes;
    $index = 0;

    while ($value >= 1024 && $index < count($units) - 1) {
        $value /= 1024;
        $index++;
    }

    if ($index === 0) {
        return sprintf('%d %s', (int)$value, $units[$index]);
    }

    return sprintf('%.2f %s', $value, $units[$index]);
}

/* 元数据 & 封面 -------------------------------------------------------- */

function buildMetadata(string $audioPath): ?array
{
    $probe = probeAudio($audioPath);
    if ($probe === null) {
        return null;
    }

    $format      = $probe['format'] ?? [];
    $streams     = $probe['streams'] ?? [];
    $audioStream = null;
    foreach ($streams as $stream) {
        if (($stream['codec_type'] ?? '') === 'audio') {
            $audioStream = $stream;
            break;
        }
    }

    $tags = [];
    if (isset($format['tags']) && is_array($format['tags'])) {
        foreach ($format['tags'] as $key => $value) {
            $tags[strtolower($key)] = is_scalar($value) ? (string)$value : json_encode($value);
        }
    }

    $title  = trim((string)($tags['title'] ?? ''));
    $artist = trim((string)($tags['artist'] ?? ($tags['album_artist'] ?? '')));
    $album  = trim((string)($tags['album'] ?? ''));

    if ($title === '') {
        $title = pathinfo($audioPath, PATHINFO_FILENAME) ?: basename($audioPath);
    }

    $duration = isset($format['duration']) ? (float)$format['duration'] : null;
    $bitRate  = isset($format['bit_rate']) ? (int)$format['bit_rate'] : null;
    $size     = isset($format['size']) ? (int)$format['size'] : filesize($audioPath);
    $mtime    = filemtime($audioPath) ?: time();

    $metadata = [
        'title'         => $title,
        'artist'        => $artist !== '' ? $artist : null,
        'album'         => $album !== '' ? $album : null,
        'duration'      => $duration,
        'bit_rate'      => $bitRate,
        'filesize'      => $size,
        'last_modified' => $mtime,
        'sample_rate'   => isset($audioStream['sample_rate']) ? (int)$audioStream['sample_rate'] : null,
        'channels'      => isset($audioStream['channels']) ? (int)$audioStream['channels'] : null,
        'codec_name'    => $audioStream['codec_name'] ?? null,
        'format_name'   => $format['format_name'] ?? null,
        'tags'          => $tags,
    ];

    $artwork = ensureArtwork($audioPath, $probe);
    if ($artwork['cover'] !== null) {
        $metadata['cover_file'] = relativePath($artwork['cover']);
    }
    if ($artwork['thumb'] !== null) {
        $metadata['thumbnail_file'] = relativePath($artwork['thumb']);
    }

    return $metadata;
}

function ensureArtwork(string $audioPath, array $probe): array
{
    $coverPath = artworkPath($audioPath, false);
    $thumbPath = artworkPath($audioPath, true);

    $audioTime = filemtime($audioPath) ?: time();

    $coverFresh = is_file($coverPath) && filemtime($coverPath) >= $audioTime;
    $thumbFresh = is_file($thumbPath) && filemtime($thumbPath) >= ($coverFresh ? filemtime($coverPath) : $audioTime);

    if (!$coverFresh && hasArtworkStream($probe)) {
        if (!extractArtwork($audioPath, $coverPath)) {
            @unlink($coverPath);
        } else {
            $coverFresh = true;
        }
    }

    if (!$coverFresh) {
        $external = discoverExternalArtwork($audioPath);
        if ($external !== null) {
            if (convertImageToWebp($external, $coverPath)) {
                $coverFresh = true;
            } else {
                @unlink($coverPath);
            }
        }
    }

    if ($coverFresh && !$thumbFresh) {
        if (!createThumbnail($coverPath, $thumbPath)) {
            @unlink($thumbPath);
        } else {
            $thumbFresh = true;
        }
    }

    if (!$coverFresh) {
        @unlink($coverPath);
    }
    if (!$thumbFresh) {
        @unlink($thumbPath);
    }

    return [
        'cover' => $coverFresh ? $coverPath : null,
        'thumb' => $thumbFresh ? $thumbPath : null,
    ];
}

function artworkPath(string $audioPath, bool $thumbnail): string
{
    $dir = dirname($audioPath);
    $base = pathinfo($audioPath, PATHINFO_FILENAME);
    $suffix = $thumbnail ? '.thumb.webp' : '.cover.webp';
    return $dir . DIRECTORY_SEPARATOR . $base . $suffix;
}

function hasArtworkStream(array $probe): bool
{
    foreach ($probe['streams'] ?? [] as $stream) {
        $type = $stream['codec_type'] ?? '';
        $attached = (int)($stream['disposition']['attached_pic'] ?? 0) === 1;
        if ($type === 'video' || $attached) {
            return true;
        }
    }
    return false;
}

function extractArtwork(string $audioPath, string $target): bool
{
    if (!commandExists('ffmpeg')) {
        return false;
    }

    $cmd = [
        'ffmpeg',
        '-y',
        '-hide_banner',
        '-loglevel', 'error',
        '-i', $audioPath,
        '-map', '0:v:0',
        '-frames:v', '1',
        '-vf', "scale='min(1024,iw)':-1",
        '-q:v', '2',
        '-c:v', 'libwebp',
        $target,
    ];

    $result = runCommand($cmd);
    return $result['code'] === 0 && is_file($target);
}

function discoverExternalArtwork(string $audioPath): ?string
{
    $dir  = dirname($audioPath);
    $candidates = [
        'cover.jpg', 'cover.jpeg', 'cover.png', 'folder.jpg', 'folder.jpeg', 'folder.png', 'front.jpg', 'front.png',
    ];

    foreach ($candidates as $name) {
        $candidate = $dir . DIRECTORY_SEPARATOR . $name;
        if (is_file($candidate)) {
            return $candidate;
        }
    }

    return null;
}

function convertImageToWebp(string $source, string $target): bool
{
    if (!commandExists('ffmpeg')) {
        return false;
    }

    $cmd = [
        'ffmpeg',
        '-y',
        '-hide_banner',
        '-loglevel', 'error',
        '-i', $source,
        '-vf', "scale='min(1024,iw)':-1",
        '-compression_level', '6',
        '-quality', '85',
        $target,
    ];

    $result = runCommand($cmd);
    return $result['code'] === 0 && is_file($target);
}

function createThumbnail(string $coverPath, string $thumbPath): bool
{
    if (!commandExists('ffmpeg')) {
        return false;
    }

    $cmd = [
        'ffmpeg',
        '-y',
        '-hide_banner',
        '-loglevel', 'error',
        '-i', $coverPath,
        '-vf', "scale='min(256,iw)':-1",
        '-compression_level', '6',
        '-quality', '80',
        $thumbPath,
    ];

    $result = runCommand($cmd);
    return $result['code'] === 0 && is_file($thumbPath);
}

function probeAudio(string $audioPath): ?array
{
    if (!commandExists('ffprobe')) {
        return null;
    }

    $cmd = [
        'ffprobe',
        '-v', 'error',
        '-show_format',
        '-show_streams',
        '-of', 'json',
        $audioPath,
    ];

    $result = runCommand($cmd);
    if ($result['code'] !== 0) {
        return null;
    }

    $decoded = json_decode($result['stdout'], true);
    return is_array($decoded) ? $decoded : null;
}

function commandExists(string $binary): bool
{
    static $cache = [];
    if (array_key_exists($binary, $cache)) {
        return $cache[$binary];
    }

    $result = runCommand(['which', $binary]);
    $cache[$binary] = $result['code'] === 0;
    return $cache[$binary];
}

function runCommand(array $command): array
{
    $spec = [
        0 => ['pipe', 'r'],
        1 => ['pipe', 'w'],
        2 => ['pipe', 'w'],
    ];

    $process = proc_open($command, $spec, $pipes, null, null, ['bypass_shell' => true]);
    if (!is_resource($process)) {
        return ['code' => 1, 'stdout' => '', 'stderr' => 'proc_open failed'];
    }

    fclose($pipes[0]);
    $stdout = stream_get_contents($pipes[1]);
    fclose($pipes[1]);
    $stderr = stream_get_contents($pipes[2]);
    fclose($pipes[2]);
    $code = proc_close($process);

    return [
        'code'   => $code,
        'stdout' => $stdout === false ? '' : $stdout,
        'stderr' => $stderr === false ? '' : $stderr,
    ];
}

function serveHtmlUi(): void
{
    $title = 'Misuzu Music Library';
    $secretHint = SECRET_CODE !== '' ? '（需输入访问代码）' : '';
    $heading = trim($title . ' ' . $secretHint);
    $stats = libraryStats();
    $sampleTracks = listAudioRelativePaths(500);
    $trackListText = $sampleTracks === []
        ? "(未找到音频文件或暂无权限)"
        : implode("\n", $sampleTracks);
    header('Content-Type: text/html; charset=utf-8');

    $html = <<<'HTML'
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>{{PAGE_TITLE}}</title>
    <link rel="stylesheet" href="https://static2.sharepointonline.com/files/fabric/office-ui-fabric-core/11.1.0/css/fabric.min.css">
    <style>
        body { font-family: 'Segoe UI', Tahoma, sans-serif; margin: 0; background:#f5f5f5; }
        header { background:#0078d4; color:#fff; padding:16px; }
        main { padding: 24px; max-width: 1200px; margin: 0 auto; }
        .card { background:#fff; border-radius:8px; padding:16px; box-shadow:0 2px 8px rgba(0,0,0,0.08); margin-bottom:16px; }
        .tracks { display:grid; grid-template-columns: repeat(auto-fill, minmax(220px,1fr)); gap:16px; }
        .track { background:#fff; border-radius:8px; box-shadow:0 1px 4px rgba(0,0,0,0.1); padding:12px; display:flex; flex-direction:column; gap:12px; }
        .track img { width:100%; border-radius:6px; object-fit:cover; aspect-ratio:1/1; }
        .actions { display:flex; gap:8px; }
        .hidden { display:none; }
        form.upload { display:flex; flex-direction:column; gap:12px; }
        button { cursor:pointer; }
        .stats { margin-top:16px; line-height:1.6; }
        .stats code { background:#f0f0f0; padding:2px 4px; border-radius:4px; }
        .track-debug { background:#fafafa; border:1px solid #e1e1e1; border-radius:6px; padding:12px; max-height:240px; overflow:auto; white-space:pre-wrap; font-family:"Fira Code", "Consolas", monospace; }
    </style>
</head>
<body class="ms-Fabric">
    <header>
        <h1 style="margin:0; font-size:22px;">{{HEADING}}</h1>
    </header>
    <main>
        <div class="card">
            <div class="ms-TextField">
                <label class="ms-Label">访问代码</label>
                <input id="codeInput" class="ms-TextField-field" type="password" placeholder="请输入 SECRET CODE">
            </div>
            <div class="actions" style="margin-top:12px;">
                <button id="loadBtn" class="ms-Button ms-Button--primary"><span class="ms-Button-label">加载曲库</span></button>
                <button id="forgetBtn" class="ms-Button"><span class="ms-Button-label">清除记忆</span></button>
            </div>
            <p class="ms-fontSize-s stats">
                曲库路径：<code>{{LIB_PATH}}</code><br>
                音频文件：{{AUDIO_COUNT}} 个，总体积 {{AUDIO_SIZE}}<br>
                全部文件（含封面/元数据）：{{TOTAL_FILES}} 个
            </p>
        </div>
        <div class="card">
            <form id="uploadForm" class="upload" enctype="multipart/form-data">
                <label class="ms-Label">上传音乐文件</label>
                <input type="file" id="musicFile" name="music_file" accept="audio/*">
                <button class="ms-Button ms-Button--primary" type="submit"><span class="ms-Button-label">上传</span></button>
                <span id="uploadStatus" class="ms-TextField-description"></span>
            </form>
        </div>
        <div class="card">
            <h3 class="ms-fontWeight-semibold" style="margin-top:0;">调试：音频文件列表 (最多 500 条)</h3>
            <pre class="track-debug">{{TRACK_LIST}}</pre>
        </div>
        <div class="card">
            <h2 style="margin-top:0;">曲目列表</h2>
            <div id="tracks" class="tracks"></div>
        </div>
    </main>
    <template id="trackTemplate">
        <div class="track">
            <img class="cover" alt="封面" src="" loading="lazy">
            <div>
                <div class="ms-fontWeight-semibold title"></div>
                <div class="ms-fontSize-s artist"></div>
                <div class="ms-fontSize-xs album"></div>
                <div class="ms-fontSize-xs duration"></div>
            </div>
            <audio class="player" controls preload="none"></audio>
            <div class="actions">
                <button class="ms-Button ms-Button--default downloadBtn"><span class="ms-Button-label">下载</span></button>
            </div>
        </div>
    </template>
    <script>
        const codeInput = document.getElementById('codeInput');
        const loadBtn = document.getElementById('loadBtn');
        const forgetBtn = document.getElementById('forgetBtn');
        const tracksEl = document.getElementById('tracks');
        const template = document.getElementById('trackTemplate');
        const uploadForm = document.getElementById('uploadForm');
        const uploadStatus = document.getElementById('uploadStatus');

        codeInput.value = localStorage.getItem('misuzu_code') || '';

        loadBtn.addEventListener('click', () => {
            const code = codeInput.value.trim();
            if (!code) {
                alert('请先输入访问代码');
                return;
            }
            localStorage.setItem('misuzu_code', code);
            fetchTracks(code);
        });

        forgetBtn.addEventListener('click', () => {
            localStorage.removeItem('misuzu_code');
            codeInput.value = '';
            tracksEl.textContent = '';
        });

        uploadForm.addEventListener('submit', async (evt) => {
            evt.preventDefault();
            const code = codeInput.value.trim();
            if (!code) {
                alert('请先输入访问代码');
                return;
            }
            const file = document.getElementById('musicFile').files[0];
            if (!file) {
                alert('请选择文件');
                return;
            }
            const formData = new FormData();
            formData.append('music_file', file);
            formData.append('action', 'upload');
            formData.append('code', code);
            uploadStatus.textContent = '上传中...';
            try {
                const resp = await fetch(window.location.pathname, {
                    method: 'POST',
                    body: formData,
                });
                const data = await resp.json();
                if (!resp.ok || !data.success) {
                    throw new Error(data.message || '上传失败');
                }
                uploadStatus.textContent = '上传成功';
                fetchTracks(code);
                uploadForm.reset();
            } catch (err) {
                uploadStatus.textContent = err.message;
            }
        });

        async function fetchTracks(code) {
            tracksEl.textContent = '加载中...';
            console.log('fetchTracks code', code);
            try {
                const query = 'action=list&code=' + encodeURIComponent(code);
                const resp = await fetch(window.location.pathname + '?' + query);
                console.log('fetchTracks response status', resp.status);
                const data = await resp.json();
                if (!resp.ok || !data.success) {
                    throw new Error(data.message || '加载失败');
                }
                renderTracks(data.tracks || [], code);
            } catch (err) {
                tracksEl.textContent = err.message;
            }
        }

        function renderTracks(tracks, code) {
            tracksEl.textContent = '';
            if (!tracks.length) {
                tracksEl.textContent = '暂无曲目';
                return;
            }
            const frag = document.createDocumentFragment();
            for (const track of tracks) {
                const clone = template.content.cloneNode(true);
                const cover = clone.querySelector('.cover');
                const player = clone.querySelector('.player');
                const downloadBtn = clone.querySelector('.downloadBtn');
                const metadata = track.metadata || {};
                clone.querySelector('.title').textContent = metadata.title || '未知标题';
                clone.querySelector('.artist').textContent = metadata.artist || '未知艺人';
                clone.querySelector('.album').textContent = metadata.album || '';
                clone.querySelector('.duration').textContent = formatDuration(metadata.duration || 0);

                const name = metadata.title || track.relative_path || '未知标题';
                console.log('track entry', name, track.relative_path);
                const streamUrl = buildUrl('stream', track.relative_path || '', code);
                player.src = streamUrl;
                downloadBtn.addEventListener('click', () => window.open(streamUrl, '_blank'));

                if (track.thumbnail_path) {
                    cover.src = buildUrl('thumbnail', track.thumbnail_path, code);
                } else if (track.cover_path) {
                    cover.src = buildUrl('cover', track.cover_path, code);
                } else {
                    cover.classList.add('hidden');
                }

                frag.appendChild(clone);
            }
            tracksEl.appendChild(frag);
        }

        function buildUrl(action, path, code) {
            let query = 'action=' + encodeURIComponent(action) + '&code=' + encodeURIComponent(code);
            if (path) {
                query += '&path=' + encodeURIComponent(path);
            }
            return window.location.pathname + '?' + query;
        }

        function formatDuration(value) {
            const seconds = Number(value);
            if (!Number.isFinite(seconds) || seconds <= 0) {
                return '';
            }
            const mins = Math.floor(seconds / 60);
            const secs = Math.round(seconds % 60).toString().padStart(2, '0');
            return mins + ':' + secs;
        }

        if (codeInput.value) {
            fetchTracks(codeInput.value.trim());
        }
    </script>
</body>
</html>
HTML;

    echo strtr($html, [
        '{{PAGE_TITLE}}' => htmlspecialchars($title, ENT_QUOTES, 'UTF-8'),
        '{{HEADING}}'    => htmlspecialchars($heading, ENT_QUOTES, 'UTF-8'),
        '{{LIB_PATH}}'   => htmlspecialchars($stats['path'], ENT_QUOTES, 'UTF-8'),
        '{{AUDIO_COUNT}}' => number_format($stats['audio_count']),
        '{{TOTAL_FILES}}' => number_format($stats['total_files']),
        '{{AUDIO_SIZE}}'  => formatBytes((int)$stats['audio_bytes']),
        '{{TRACK_LIST}}'  => htmlspecialchars($trackListText, ENT_QUOTES, 'UTF-8'),
    ]);
    exit;
}

function loadTrackMetadata(string $audioPath, bool $forceRefresh = false): ?array
{
    $metaPath = metadataPath($audioPath);

    if (!$forceRefresh && is_file($metaPath)) {
        $raw = file_get_contents($metaPath);
        if ($raw !== false) {
            $decoded = json_decode($raw, true);
            if (is_array($decoded)) {
                return $decoded;
            }
        }
    }

    $metadata = buildMetadata($audioPath);
    if ($metadata === null) {
        return null;
    }

    $metaDir = dirname($metaPath);
    if (!is_dir($metaDir)) {
        @mkdir($metaDir, 0775, true);
    }

    @file_put_contents(
        $metaPath,
        json_encode($metadata, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES)
    );

    return $metadata;
}

function metadataPath(string $audioPath): string
{
    $dir      = dirname($audioPath);
    $filename = pathinfo($audioPath, PATHINFO_FILENAME) . '.json';
    return $dir . DIRECTORY_SEPARATOR . $filename;
}
