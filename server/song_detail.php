<?php
declare(strict_types=1);

header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Accept, Origin');

$method = strtoupper($_SERVER['REQUEST_METHOD'] ?? 'GET');
if ($method === 'OPTIONS') {
    http_response_code(204);
    exit;
}

$storageDir = __DIR__ . '/song_details';
if (!is_dir($storageDir) && !mkdir($storageDir, 0775, true)) {
    respondJson(500, '无法创建歌曲详情目录');
}

switch ($method) {
    case 'GET':
        handleFetchDetail($storageDir);
        break;

    case 'POST':
        handleSaveDetail($storageDir);
        break;

    default:
        respondJson(405, '仅支持 GET / POST 请求');
}

function handleFetchDetail(string $dir): void
{
    $title = isset($_GET['title']) && is_string($_GET['title']) ? $_GET['title'] : '';
    $manual = isset($_GET['file']) && is_string($_GET['file']) ? $_GET['file'] : '';

    $base = $manual !== '' ? $manual : $title;
    $fileBase = sanitizeTitle($base !== '' ? $base : $title);
    $fileName = ensureTxtSuffix($fileBase);
    $path = $dir . DIRECTORY_SEPARATOR . $fileName;

    if (!is_file($path)) {
        respondJson(200, 'ok', [
            'file' => $fileName,
            'exists' => false,
            'content' => '',
        ]);
    }

    $content = file_get_contents($path);
    if ($content === false) {
        respondJson(500, '无法读取歌曲详情文件');
    }

    respondJson(200, 'ok', [
        'file' => $fileName,
        'exists' => true,
        'content' => $content,
        'updated_at' => filemtime($path),
    ]);
}

function handleSaveDetail(string $dir): void
{
    $raw = file_get_contents('php://input');
    if ($raw === false) {
        respondJson(400, '无法读取请求体');
    }

    try {
        $decoded = json_decode($raw, true, flags: JSON_THROW_ON_ERROR);
    } catch (JsonException $exception) {
        respondJson(400, 'JSON 解析失败: ' . $exception->getMessage());
    }

    if (!is_array($decoded)) {
        respondJson(400, '请求体必须是 JSON 对象');
    }

    $title = isset($decoded['title']) && is_string($decoded['title'])
        ? $decoded['title']
        : '';
    $manual = isset($decoded['file']) && is_string($decoded['file'])
        ? $decoded['file']
        : '';
    $content = isset($decoded['content']) && is_string($decoded['content'])
        ? $decoded['content']
        : '';

    if ($title === '' && $manual === '') {
        respondJson(400, '缺少歌曲标题');
    }

    $fileBase = sanitizeTitle($manual !== '' ? $manual : $title);
    $fileName = ensureTxtSuffix($fileBase);
    $path = $dir . DIRECTORY_SEPARATOR . $fileName;

    $created = !file_exists($path);
    $bytes = file_put_contents($path, $content, LOCK_EX);
    if ($bytes === false) {
        respondJson(500, '保存歌曲详情失败');
    }

    if ($created) {
        @chmod($path, 0664);
    }

    respondJson(200, '保存成功', [
        'file' => $fileName,
        'created' => $created,
        'content' => $content,
        'bytes' => $bytes,
        'updated_at' => filemtime($path),
    ]);
}

function sanitizeTitle(string $title): string
{
    $normalized = preg_replace('/[\p{P}\p{S}\s]+/u', '', $title);
    if ($normalized === null) {
        $normalized = '';
    }
    $normalized = trim($normalized);
    if ($normalized === '') {
        return 'untitled_' . sprintf('%u', crc32($title));
    }
    if (mb_strlen($normalized, 'UTF-8') > 80) {
        $normalized = mb_substr($normalized, 0, 80, 'UTF-8');
    }
    return $normalized;
}

function ensureTxtSuffix(string $name): string
{
    $trimmed = trim($name);
    if ($trimmed === '') {
        $trimmed = 'untitled_' . time();
    }
    if (!str_ends_with(strtolower($trimmed), '.txt')) {
        $trimmed .= '.txt';
    }
    return $trimmed;
}

function respondJson(int $status, string $message, array $extra = []): void
{
    http_response_code($status);
    header('Content-Type: application/json; charset=utf-8');
    $success = $status >= 200 && $status < 300;
    echo json_encode(
        [
            'success' => $success,
            'message' => $message,
        ] + $extra,
        JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES
    );
    exit;
}
