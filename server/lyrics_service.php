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
$action = $_REQUEST['action'] ?? null;
$wantsJson = isset($_GET['format']) && $_GET['format'] === 'json';
$wantsHtml = !$wantsJson
    && !isset($_GET['file'])
    && ($action === null)
    && (isset($_SERVER['HTTP_ACCEPT'])
        ? str_contains($_SERVER['HTTP_ACCEPT'], 'text/html')
        : true);

if ($method === 'GET' && $wantsHtml) {
    serveHtmlUi();
    exit;
}

switch ($method) {
    case 'GET':
        if ($action === 'list' || $wantsJson || (!isset($_GET['file']) && $action === null)) {
            handleList($lyricsDir);
            return;
        }
        $requestedFile = $_GET['file'] ?? null;
        if ($requestedFile === null) {
            respondJson(400, '缺少 file 参数');
        }
        handleFetch($lyricsDir, $requestedFile);
        return;

    case 'POST':
        if ($action === 'save') {
            handleSave($lyricsDir, $_POST['file'] ?? '', $_POST['content'] ?? '');
            return;
        }
        respondJson(400, '未知的操作');

    default:
        respondJson(405, '仅支持 GET / POST 请求');
}
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

function handleSave(string $lyricsDir, string $filename, string $content): void
{
    $sanitized = sanitizeFilename($filename);
    if ($sanitized === null) {
        respondJson(400, '非法的文件名');
    }
    if (!str_ends_with(strtolower($sanitized), '.lrc')) {
        $sanitized .= '.lrc';
    }

    $targetPath = $lyricsDir . DIRECTORY_SEPARATOR . $sanitized;
    if (!is_dir($lyricsDir) && !mkdir($lyricsDir, 0775, true)) {
        respondJson(500, '无法创建歌词目录');
    }

    $bytes = file_put_contents($targetPath, $content);
    if ($bytes === false) {
        respondJson(500, '保存歌词失败');
    }

    respondJson(200, '保存成功', [
        'file' => $sanitized,
        'bytes' => $bytes,
        'updated_at' => filemtime($targetPath),
    ]);
}

function handleFetch(string $lyricsDir, string $requested): void
{
    $trimmed = trim($requested);
    if ($trimmed === '') {
        respondJson(400, '文件名不能为空');
    }

    $sanitized = sanitizeFilename($trimmed);
    if ($sanitized === null) {
        respondJson(400, '非法的文件名');
    }

    $fullPath = realpath($lyricsDir . DIRECTORY_SEPARATOR . $sanitized);
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

function sanitizeFilename(string $name): ?string
{
    $trimmed = trim($name);
    if ($trimmed === '') {
        return null;
    }
    if (str_contains($trimmed, "\0") || str_contains($trimmed, '..') ||
        str_contains($trimmed, '/') || str_contains($trimmed, '\\')) {
        return null;
    }
    return $trimmed;
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

function serveHtmlUi(): void
{
    header('Content-Type: text/html; charset=utf-8');
    $html = <<<HTML
<!DOCTYPE html>
<html lang="zh-CN">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>Misuzu 云歌词管理器</title>
    <script type="module" src="https://cdn.jsdelivr.net/npm/@fluentui/web-components/dist/web-components.min.js"></script>
    <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/@fluentui/tokens/dist/css/global.mint.css" />
    <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/highlight.js@11.9.0/styles/vs2015.min.css" />
    <script src="https://cdn.jsdelivr.net/npm/highlight.js@11.9.0/lib/common.min.js"></script>
    <style>
      :root {
        color-scheme: dark light;
      }
      body {
        margin: 0;
        font-family: 'Segoe UI', 'Microsoft YaHei', system-ui, sans-serif;
        background: var(--neutral-layer-1);
        color: var(--neutral-foreground-rest);
      }
      header {
        padding: 16px 24px;
        display: flex;
        align-items: center;
        justify-content: space-between;
        border-bottom: 1px solid var(--neutral-stroke-rest);
      }
      main {
        display: flex;
        min-height: calc(100vh - 72px);
      }
      .sidebar {
        width: 320px;
        max-width: 80vw;
        border-right: 1px solid var(--neutral-stroke-rest);
        display: flex;
        flex-direction: column;
      }
      .sidebar header {
        padding: 16px;
        border: none;
      }
      .file-list {
        flex: 1;
        overflow: auto;
        padding: 0 8px 24px;
      }
      .file-item {
        display: flex;
        align-items: center;
        justify-content: space-between;
        padding: 12px;
        margin: 6px 0;
        border-radius: 8px;
        cursor: pointer;
        background: transparent;
        transition: background 0.2s ease;
      }
      .file-item:hover {
        background: var(--neutral-layer-2);
      }
      .file-item.active {
        background: var(--accent-fill-rest);
        color: var(--accent-foreground-rest);
      }
      .editor {
        flex: 1;
        display: flex;
        flex-direction: column;
        min-width: 0;
      }
      .editor-header {
        padding: 16px 24px;
        border-bottom: 1px solid var(--neutral-stroke-rest);
        display: flex;
        gap: 12px;
        flex-wrap: wrap;
      }
      .editor-container {
        flex: 1;
        display: flex;
        flex-direction: column;
        gap: 12px;
        padding: 16px 24px 24px;
      }
      fluent-text-area {
        width: 100%;
        height: 280px;
      }
      .preview {
        flex: 1;
        overflow: auto;
        background: var(--neutral-layer-2);
        border-radius: 12px;
        padding: 16px;
      }
      pre {
        margin: 0;
        white-space: pre-wrap;
        word-break: break-word;
      }
      .mobile-toggle {
        display: none;
      }
      @media (max-width: 900px) {
        main {
          flex-direction: column;
        }
        .sidebar {
          width: 100%;
          max-width: none;
          border-right: none;
          border-bottom: 1px solid var(--neutral-stroke-rest);
        }
        .editor {
          min-height: 60vh;
        }
      }
    </style>
  </head>
  <body>
    <header>
      <div>
        <h1 style="margin:0;font-size:20px;font-weight:600;">Misuzu 云歌词管理器</h1>
        <p style="margin:4px 0 0;font-size:12px;color:var(--neutral-foreground-hint);">
          浏览、编辑、创建 LRC 歌词文件，变更会即时写入服务器。
        </p>
      </div>
      <fluent-button appearance="accent" id="createBtn">新建 LRC</fluent-button>
    </header>
    <main>
      <section class="sidebar">
        <header>
          <fluent-search id="searchInput" placeholder="搜索文件..." aria-label="搜索歌词文件"></fluent-search>
        </header>
        <div class="file-list" id="fileList">
          <fluent-progress-ring></fluent-progress-ring>
        </div>
      </section>
      <section class="editor">
        <div class="editor-header">
          <fluent-text-field id="fileNameInput" placeholder="文件名，例如 Artist - Title.lrc" style="flex:1;" aria-label="文件名"></fluent-text-field>
          <fluent-button id="saveBtn" appearance="accent">保存 (Ctrl+S)</fluent-button>
          <fluent-button id="reloadBtn">重新加载</fluent-button>
        </div>
        <div class="editor-container">
          <fluent-text-area id="editor" resize="vertical" placeholder="在此处编辑 LRC 内容..."></fluent-text-area>
          <div class="preview">
            <h3 style="margin:0 0 12px;font-size:14px;">预览</h3>
            <pre><code id="preview" class="language-plaintext"></code></pre>
          </div>
        </div>
      </section>
    </main>

    <template id="fileItemTemplate">
      <div class="file-item">
        <span class="file-name"></span>
        <small class="file-meta" style="opacity:.65;"></small>
      </div>
    </template>

    <script>
      const apiUrl = new URL(window.location.href);

      const ui = {
        fileList: document.getElementById('fileList'),
        template: document.getElementById('fileItemTemplate'),
        editor: document.getElementById('editor'),
        preview: document.getElementById('preview'),
        saveBtn: document.getElementById('saveBtn'),
        reloadBtn: document.getElementById('reloadBtn'),
        createBtn: document.getElementById('createBtn'),
        fileNameInput: document.getElementById('fileNameInput'),
        searchInput: document.getElementById('searchInput'),
      };

      let state = {
        files: [],
        filtered: [],
        activeFile: null,
        isDirty: false,
      };

      function showMessage(message, appearance = 'accent') {
        const toast = document.createElement('fluent-toast');
        toast.innerText = message;
        toast.appearance = appearance;
        document.body.appendChild(toast);
        setTimeout(() => toast.remove(), 3200);
      }

      async function fetchList() {
        ui.fileList.innerHTML = '<fluent-progress-ring></fluent-progress-ring>';
        try {
          const url = new URL(window.location.href);
          url.searchParams.set('action', 'list');
          url.searchParams.set('format', 'json');
          const response = await fetch(url);
          if (!response.ok) {
            throw new Error('无法获取列表');
          }
          const data = await response.json();
          state.files = data.files || [];
          state.filtered = state.files;
          renderFileList();
        } catch (error) {
          ui.fileList.innerHTML = '<fluent-badge appearance="accent">加载失败</fluent-badge>';
          console.error(error);
        }
      }

      function renderFileList() {
        ui.fileList.innerHTML = '';
        if (!state.filtered.length) {
          ui.fileList.innerHTML = '<fluent-badge appearance="accent">暂无歌词文件</fluent-badge>';
          return;
        }

        state.filtered.forEach((file) => {
          const node = ui.template.content.cloneNode(true);
          const item = node.querySelector('.file-item');
          item.dataset.file = file;
          item.classList.toggle('active', file === state.activeFile);
          node.querySelector('.file-name').textContent = file;
          node.querySelector('.file-meta').textContent = file.toLowerCase().endsWith('.lrc') ? 'LRC' : '';
          item.addEventListener('click', () => {
            if (state.isDirty && !confirm('内容尚未保存，确定离开？')) {
              return;
            }
            loadFile(file);
          });
          ui.fileList.appendChild(node);
        });
      }

      async function loadFile(file) {
        try {
          const url = new URL(window.location.href);
          url.searchParams.set('file', file);
          const response = await fetch(url);
          if (!response.ok) {
            throw new Error('加载失败');
          }
          const text = await response.text();
          state.activeFile = file;
          ui.fileNameInput.value = file;
          ui.editor.value = text;
          ui.preview.textContent = text;
          hljs.highlightElement(ui.preview);
          state.isDirty = false;
          renderFileList();
          showMessage('已加载 ' + file, 'accent');
        } catch (error) {
          console.error(error);
          showMessage('加载失败: ' + error.message, 'error');
        }
      }

      async function saveFile() {
        const filename = ui.fileNameInput.value.trim();
        if (!filename) {
          showMessage('请先填写文件名', 'error');
          return;
        }

        const body = new URLSearchParams();
        body.set('action', 'save');
        body.set('file', filename);
        body.set('content', ui.editor.value);

        try {
          const response = await fetch(window.location.href, {
            method: 'POST',
            headers: {
              'Content-Type': 'application/x-www-form-urlencoded;charset=utf-8',
            },
            body: body.toString(),
          });
          const data = await response.json();
          if (!response.ok || !data.success) {
            throw new Error(data.message || '保存失败');
          }
          state.isDirty = false;
          state.activeFile = data.file;
          ui.fileNameInput.value = data.file;
          await fetchList();
          showMessage('保存成功');
        } catch (error) {
          console.error(error);
          showMessage('保存失败: ' + error.message, 'error');
        }
      }

      ui.editor.addEventListener('input', () => {
        state.isDirty = true;
        ui.preview.textContent = ui.editor.value;
        hljs.highlightElement(ui.preview);
      });

      ui.saveBtn.addEventListener('click', saveFile);
      ui.reloadBtn.addEventListener('click', () => {
        if (!state.activeFile) {
          showMessage('当前没有加载的文件', 'error');
          return;
        }
        loadFile(state.activeFile);
      });

      ui.createBtn.addEventListener('click', () => {
        const name = prompt('新建 LRC 文件名', 'New Song.lrc');
        if (!name) return;
        if (state.isDirty && !confirm('当前内容未保存，确定继续？')) {
          return;
        }
        ui.fileNameInput.value = name.endsWith('.lrc') ? name : name + '.lrc';
        ui.editor.value = '';
        ui.preview.textContent = '';
        state.activeFile = null;
        state.isDirty = true;
        renderFileList();
      });

      ui.searchInput.addEventListener('input', (event) => {
        const keyword = event.target.value.trim().toLowerCase();
        state.filtered = keyword
          ? state.files.filter((file) => file.toLowerCase().includes(keyword))
          : state.files;
        renderFileList();
      });

      window.addEventListener('keydown', (event) => {
        if ((event.ctrlKey || event.metaKey) && event.key === 's') {
          event.preventDefault();
          saveFile();
        }
      });

      window.addEventListener('beforeunload', (event) => {
        if (state.isDirty) {
          event.preventDefault();
          event.returnValue = '';
        }
      });

      fetchList();
    </script>
  </body>
</html>
HTML;
    echo $html;
}
