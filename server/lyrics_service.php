<?php
declare(strict_types=1);

/**
 * Misuzu Music 云歌词接口
 *
 * GET lyrics_service.php
 *    -> 返回 { success: true, files: ["Artist - Song.lrc", ...] }
 * GET lyrics_service.php?file=<FILENAME>
 *    -> 返回指定 LRC 文件内容（文本）
 */

$lyricsDir = __DIR__ . '/lrcs';

if (!is_dir($lyricsDir)) {
    respondJson(500, '歌词目录不存在或无法访问');
}

$method = strtoupper($_SERVER['REQUEST_METHOD'] ?? 'GET');
if ($method !== 'GET') {
    respondJson(405, '仅支持 GET 请求');
}

$requestedFile = $_GET['file'] ?? null;
if ($requestedFile === null || trim($requestedFile) === '') {
    handleList($lyricsDir);
    exit;
}

handleFetch($lyricsDir, $requestedFile);
exit;

function handleList(string $lyricsDir): void
{
    $files = [];
    $iterator = new DirectoryIterator($lyricsDir);
    foreach ($iterator as $entry) {
        if ($entry->isDot() || !$entry->isFile()) {
            continue;
        }
        if (strtolower($entry->getExtension()) !== 'lrc') {
            continue;
        }
        $files[] = $entry->getFilename();
    }

    natcasesort($files);

    respondJson(200, 'ok', [
        'files' => array_values($files),
        'updated_at' => filemtime($lyricsDir),
    ]);
}

function handleFetch(string $lyricsDir, string $requested): void
{
    $trimmed = trim($requested);
    if ($trimmed === '') {
        respondJson(400, '文件名不能为空');
    }

    if (str_contains($trimmed, "\0") || str_contains($trimmed, '..') || str_contains($trimmed, '/')) {
        respondJson(400, '非法的文件名');
    }

    $fullPath = realpath($lyricsDir . DIRECTORY_SEPARATOR . $trimmed);
    if ($fullPath === false) {
        respondJson(404, '未找到指定歌词');
    }

    $lyricsDirReal = realpath($lyricsDir);
    if ($lyricsDirReal === false || !str_starts_with($fullPath, $lyricsDirReal)) {
        respondJson(403, '无权访问该文件');
    }

    if (!is_file($fullPath) || strtolower(pathinfo($fullPath, PATHINFO_EXTENSION)) !== 'lrc') {
        respondJson(404, '未找到指定歌词');
    }

    $content = file_get_contents($fullPath);
    if ($content === false) {
        respondJson(500, '无法读取歌词文件');
    }

    header('Content-Type: text/plain; charset=utf-8');
    header('Content-Length: ' . filesize($fullPath));
    header('Content-Disposition: inline; filename="' . basename($fullPath) . '"');
    echo $content;
}

function respondJson(int $status, string $message, array $payload = []): void
{
    http_response_code($status);
    header('Content-Type: application/json; charset=utf-8');
    $success = $status >= 200 && $status < 300;
    echo json_encode([
        'success' => $success,
        'message' => $message,
    ] + $payload, JSON_UNESCAPED_UNICODE);
    exit;
}
