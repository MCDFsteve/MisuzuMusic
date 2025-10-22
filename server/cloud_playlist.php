<?php
declare(strict_types=1);

/**
 * Misuzu Music 云歌单接口
 *
 * 上传：POST cloud_playlist.php?action=upload&id=<CLOUD_ID>&playlist_file=<二进制文件>
 * 拉取：GET  cloud_playlist.php?action=download&id=<CLOUD_ID>
 */

$storageDir = __DIR__ . '/cloud_playlists';

if (!is_dir($storageDir) && !mkdir($storageDir, 0775, true) && !is_dir($storageDir)) {
    respondJson(500, '无法创建存储目录');
}

$method = strtoupper($_SERVER['REQUEST_METHOD'] ?? 'GET');
$action = $_REQUEST['action'] ?? ($method === 'GET' ? 'download' : '');
$cloudId = $_REQUEST['id'] ?? '';

if (!preg_match('/^[A-Za-z0-9_]{5,}$/', $cloudId)) {
    respondJson(400, 'ID 需至少 5 位，并且仅能包含字母、数字或下划线');
}

$playlistPath = $storageDir . '/' . $cloudId . '.msz';

switch ($method) {
    case 'POST':
        if ($action !== 'upload') {
            respondJson(400, '缺少有效的 action=upload');
        }
        handleUpload($playlistPath, $cloudId);
        break;

    case 'GET':
        if ($action !== 'download') {
            respondJson(400, '缺少有效的 action=download');
        }
        handleDownload($playlistPath, $cloudId);
        break;

    default:
        respondJson(405, '不支持的请求方法');
}

exit;

function handleUpload(string $playlistPath, string $cloudId): void
{
    $tmpPath = null;
    $isCustomTemp = false;

    if (!empty($_FILES['playlist_file']['tmp_name'])) {
        $tmpPath = $_FILES['playlist_file']['tmp_name'];
    } else {
        $raw = file_get_contents('php://input');
        if ($raw === false || $raw === '') {
            respondJson(400, '未检测到上传内容');
        }
        $tmpPath = tempnam(sys_get_temp_dir(), 'msz_');
        if ($tmpPath === false) {
            respondJson(500, '无法创建临时文件');
        }
        file_put_contents($tmpPath, $raw);
        $isCustomTemp = true;
    }

    $bytes = filesize($tmpPath);
    if ($bytes === false || $bytes === 0) {
        if ($isCustomTemp) {
          @unlink($tmpPath);
        }
        respondJson(400, '上传内容为空');
    }

    $saved = false;
    if (!$isCustomTemp) {
        $saved = move_uploaded_file($tmpPath, $playlistPath);
    } else {
        $saved = @rename($tmpPath, $playlistPath);
    }

    if (!$saved) {
        if ($isCustomTemp) {
            @unlink($tmpPath);
        }
        respondJson(500, '保存歌单文件失败');
    }

    respondJson(200, '上传成功', [
        'id' => $cloudId,
        'size' => filesize($playlistPath),
    ]);
}

function handleDownload(string $playlistPath, string $cloudId): void
{
    if (!is_file($playlistPath)) {
        respondJson(404, '未找到对应的云歌单');
    }

    header('Content-Type: application/octet-stream');
    header('Content-Length: ' . filesize($playlistPath));
    header('X-Playlist-Id: ' . $cloudId);
    header('Content-Disposition: attachment; filename="' . $cloudId . '.msz"');

    $fp = fopen($playlistPath, 'rb');
    if ($fp === false) {
        respondJson(500, '读取歌单文件失败');
    }

    while (!feof($fp)) {
        $chunk = fread($fp, 8192);
        if ($chunk === false) {
            fclose($fp);
            respondJson(500, '读取歌单文件失败');
        }
        echo $chunk;
    }
    fclose($fp);
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
