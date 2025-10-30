<?php
declare(strict_types=1);

/**
 * Misuzu Music 歌曲 ID 对照接口
 *
 * GET song_id_service.php?hash=<HASH>
 *   -> 返回指定哈希对应的网络 ID 信息
 * GET song_id_service.php?hash[]=<HASH1>&hash[]=<HASH2>
 *   -> 批量返回多个哈希的绑定结果
 * GET song_id_service.php?action=list
 *   -> 返回全部映射（谨慎使用，可能较大）
 *
 * POST song_id_service.php
 *   JSON: {"hash":"<HASH>", "netease_id":123456, "title":"...", "artist":"...", "album":"...", "source":"manual"}
 *   -> 创建或更新映射
 */

$storageDir = __DIR__ . '/data';
$storageFile = $storageDir . '/song_ids.json';

if (!is_dir($storageDir) && !mkdir($storageDir, 0775, true) && !is_dir($storageDir)) {
    respondJson(500, '无法创建存储目录');
}

$method = strtoupper($_SERVER['REQUEST_METHOD'] ?? 'GET');
$action = $_GET['action'] ?? null;

switch ($method) {
    case 'GET':
        if ($action === 'list') {
            handleList($storageFile);
            break;
        }
        handleFetch($storageFile);
        break;

    case 'POST':
        handleSave($storageFile);
        break;

    default:
        respondJson(405, '仅支持 GET 与 POST 请求');
}

exit;

function handleList(string $storageFile): void
{
    $entries = loadStorage($storageFile);
    respondJson(200, 'ok', ['entries' => $entries, 'count' => count($entries)]);
}

function handleFetch(string $storageFile): void
{
    $raw = $_GET['hash'] ?? null;
    if ($raw === null) {
      respondJson(400, '缺少 hash 参数');
    }

    $hashes = [];
    if (is_array($raw)) {
        $hashes = array_values($raw);
    } else {
        $hashes = [$raw];
    }

    $normalized = [];
    foreach ($hashes as $hash) {
        $sanitized = sanitizeHash($hash);
        if ($sanitized === null) {
            continue;
        }
        $normalized[$sanitized] = true;
    }

    if (empty($normalized)) {
        respondJson(400, 'hash 参数格式不正确');
    }

    $storage = loadStorage($storageFile);
    $result = [];
    foreach ($normalized as $hash => $_) {
        if (isset($storage[$hash])) {
            $result[$hash] = $storage[$hash];
        }
    }

    if (count($normalized) === 1 && empty($result)) {
        respondJson(404, '未找到对应映射');
    }

    respondJson(200, 'ok', ['entries' => $result]);
}

function handleSave(string $storageFile): void
{
    $input = file_get_contents('php://input');
    $payload = json_decode($input, true);
    if (!is_array($payload) || empty($payload)) {
        $payload = $_POST;
    }

    $hash = sanitizeHash($payload['hash'] ?? '');
    if ($hash === null) {
        respondJson(400, '缺少或非法的 hash 参数');
    }

    $neteaseId = filter_var($payload['netease_id'] ?? null, FILTER_VALIDATE_INT);
    if (!is_int($neteaseId) || $neteaseId <= 0) {
        respondJson(400, 'netease_id 必须为正整数');
    }

    $title = trim((string)($payload['title'] ?? ''));
    $artist = trim((string)($payload['artist'] ?? ''));
    $album = trim((string)($payload['album'] ?? ''));
    $source = trim((string)($payload['source'] ?? 'auto'));

    $storage = loadStorage($storageFile);
    $storage[$hash] = [
        'hash' => $hash,
        'netease_id' => $neteaseId,
        'title' => $title,
        'artist' => $artist,
        'album' => $album,
        'source' => $source,
        'updated_at' => time(),
    ];

    saveStorage($storageFile, $storage);
    respondJson(200, '保存成功', ['entry' => $storage[$hash]]);
}

function loadStorage(string $storageFile): array
{
    if (!is_file($storageFile)) {
        return [];
    }

    $raw = file_get_contents($storageFile);
    if ($raw === false || trim($raw) === '') {
        return [];
    }

    $decoded = json_decode($raw, true);
    if (!is_array($decoded)) {
        return [];
    }

    return $decoded;
}

function saveStorage(string $storageFile, array $data): void
{
    $json = json_encode($data, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE);
    if ($json === false) {
        respondJson(500, '保存失败：无法编码 JSON');
    }

    $tempFile = $storageFile . '.tmp';
    if (file_put_contents($tempFile, $json, LOCK_EX) === false) {
        respondJson(500, '写入临时文件失败');
    }
    if (!rename($tempFile, $storageFile)) {
        respondJson(500, '更新存储文件失败');
    }
}

function sanitizeHash(string $hash): ?string
{
    $trimmed = trim($hash);
    if ($trimmed === '') {
        return null;
    }
    if (!preg_match('/^[a-fA-F0-9]{8,}$/', $trimmed)) {
        return null;
    }
    return strtolower($trimmed);
}

function respondJson(int $status, string $message, array $payload = []): void
{
    http_response_code($status);
    header('Content-Type: application/json; charset=utf-8');
    $success = $status >= 200 && $status < 300;
    echo json_encode(
        ['success' => $success, 'message' => $message] + $payload,
        JSON_UNESCAPED_UNICODE
    );
    exit;
}
