import { WindowResizer } from './window_resizer.js';

const DEFAULT_LINE = '歌词加载中';
const FONT_STACK = "'PingFang SC', 'Hiragino Sans GB', 'Microsoft YaHei', 'Segoe UI', sans-serif";

const rootElement = document.getElementById('lyrics-root');
const loadingElement = document.getElementById('loading-line');
const activeLineElement = document.getElementById('active-line');
const translationElement = document.getElementById('translation-line');

const windowResizer = rootElement ? new WindowResizer(rootElement) : null;
const queueResize = () => {
  windowResizer?.scheduleResize();
};

let loadingVisible = true;

let lastRenderedTrackId = null;
let hasRenderedContent = false;

const resetRenderedState = () => {
  hasRenderedContent = false;
};

let lastPayload = null;
let currentLineText = DEFAULT_LINE;

const sanitizeText = (value) => (typeof value === 'string' ? value.trim() : '');

const isKana = (char) => /[\u3040-\u30ff\u31f0-\u31ff\uFF66-\uFF9F]/u.test(char);
const isCjk = (char) => /[\u3400-\u9FFF\uF900-\uFAFF\u{20000}-\u{2FA1F}々〆ヵヶ]/u.test(char);

const findBaseStart = (text, startIndex) => {
  let index = startIndex;
  while (index >= 0) {
    const char = text[index];
    if (isKana(char)) {
      return index + 1;
    }
    if (!isCjk(char)) {
      return index + 1;
    }
    index -= 1;
  }
  return 0;
};

const mergeTextSegments = (segments) =>
  segments.reduce((acc, segment) => {
    if (!segment) {
      return acc;
    }
    if (segment.type === 'text') {
      const text = segment.text ?? '';
      if (!text.length) {
        return acc;
      }
      const last = acc[acc.length - 1];
      if (last && last.type === 'text') {
        last.text += text;
      } else {
        acc.push({ type: 'text', text });
      }
      return acc;
    }
    acc.push({ type: 'ruby', base: segment.base, annotation: segment.annotation });
    return acc;
  }, []);

const parseFormattedLine = (rawLine) => {
  if (!rawLine || typeof rawLine !== 'string') {
    return { segments: [], plain: '', translation: null };
  }

  let text = rawLine.trim();
  let translation = null;
  const translationMatch = text.match(/<([^<>]*)>\s*$/);
  if (translationMatch) {
    translation = translationMatch[1].trim();
    text = text.slice(0, translationMatch.index).trimEnd();
  }

  const segments = [];
  let plain = '';
  let cursor = 0;

  while (cursor < text.length) {
    const annotationStart = text.indexOf('[', cursor);
    if (annotationStart === -1) {
      const remaining = text.slice(cursor);
      if (remaining.length) {
        segments.push({ type: 'text', text: remaining });
        plain += remaining;
      }
      break;
    }

    const annotationEnd = text.indexOf(']', annotationStart + 1);
    if (annotationEnd === -1) {
      const remaining = text.slice(cursor);
      if (remaining.length) {
        segments.push({ type: 'text', text: remaining });
        plain += remaining;
      }
      break;
    }

    const baseStart = findBaseStart(text, annotationStart - 1);
    const prefix = text.slice(cursor, baseStart);
    if (prefix.length) {
      segments.push({ type: 'text', text: prefix });
      plain += prefix;
    }

    const base = text.slice(baseStart, annotationStart);
    const annotation = text.slice(annotationStart + 1, annotationEnd).trim();

    if (base.length && annotation.length) {
      segments.push({ type: 'ruby', base, annotation });
      plain += base;
    } else {
      const fallback = text.slice(baseStart, annotationEnd + 1);
      if (fallback.length) {
        segments.push({ type: 'text', text: fallback });
        plain += fallback;
      }
    }

    cursor = annotationEnd + 1;
  }

  const normalizedSegments = mergeTextSegments(segments);
  const plainText = plain.length ? plain : text;

  return {
    segments: normalizedSegments,
    plain: plainText,
    translation: translation && translation.length ? translation : null,
  };
};

const shouldShowTranslation = (payload) => {
  if (payload && typeof payload.show_translation === 'boolean') {
    return payload.show_translation;
  }
  return true;
};

const setLoadingState = (isLoading, message = DEFAULT_LINE) => {
  const stateChanged = isLoading !== loadingVisible;

  if (stateChanged) {
    loadingVisible = isLoading;
    if (isLoading) {
      loadingElement.textContent = message;
      loadingElement.style.display = 'block';
      activeLineElement.style.display = 'none';
      translationElement.style.display = 'none';
    } else {
      loadingElement.style.display = 'none';
      activeLineElement.style.display = 'flex';
    }
  } else if (isLoading && typeof message === 'string') {
    loadingElement.textContent = message;
  }
  queueResize();
};

const updateFontScale = () => {
  const viewportWidth = window.innerWidth || document.documentElement.clientWidth || 0;
  const viewportHeight = window.innerHeight || document.documentElement.clientHeight || 0;
  const screenWidth = window.screen?.width ?? viewportWidth;
  const screenHeight = window.screen?.height ?? viewportHeight;

  const screenReference = Math.min(screenWidth, screenHeight);
  const viewportReference = Math.min(viewportWidth, viewportHeight);

  const screenBased = screenReference * 0.042; // 比例保持大屏字体
  const viewportBased = viewportReference * 0.18; // 窗口放大缩小时的补偿
  const computed = Math.max(screenBased, viewportBased);
  const baseSize = Math.max(36, Math.min(128, Math.round(computed)));

  document.documentElement.style.setProperty('--base-font-size', `${baseSize}px`);
  queueResize();
};

const produceTextSegment = (text) => ({ type: 'text', text });

const renderSegments = (segments) => {
  activeLineElement.innerHTML = '';
  if (!segments.length) {
    const fallback = document.createElement('span');
    fallback.className = 'segment segment--text';
    fallback.textContent = currentLineText;
    activeLineElement.appendChild(fallback);
    queueResize();
    return;
  }

  const fragment = document.createDocumentFragment();
  segments.forEach((segment) => {
    if (!segment) {
      return;
    }

    if (segment.type === 'ruby') {
      const container = document.createElement('span');
      container.className = 'segment segment--ruby';

      const annotationEl = document.createElement('span');
      annotationEl.className = 'segment__annotation';
      annotationEl.textContent = segment.annotation;

      const baseEl = document.createElement('span');
      baseEl.className = 'segment__base';
      baseEl.textContent = segment.base;

      container.appendChild(annotationEl);
      container.appendChild(baseEl);
      fragment.appendChild(container);
      return;
    }

    const textEl = document.createElement('span');
    textEl.className = 'segment segment--text';
    textEl.textContent = segment.text;
    fragment.appendChild(textEl);
  });

  activeLineElement.appendChild(fragment);
  queueResize();
};

const selectTranslation = (parsed, payload) => {
  const candidates = [
    parsed.translation,
    sanitizeText(payload?.active_translation),
    sanitizeText(payload?.next_translation),
  ];
  return candidates.find((value) => value && value.length) || '';
};

const render = (payload) => {
  if (payload) {
    lastPayload = payload;
  }
  const targetPayload = payload ?? lastPayload;

  if (!targetPayload) {
    if (!hasRenderedContent) {
      currentLineText = DEFAULT_LINE;
      activeLineElement.innerHTML = '';
      setLoadingState(true, DEFAULT_LINE);
      document.title = DEFAULT_LINE;
    }
    return;
  }

  const trackIdentifier =
    targetPayload.track_id ??
    `${sanitizeText(targetPayload.title)}::${sanitizeText(targetPayload.artist)}`;
  if (trackIdentifier && trackIdentifier !== lastRenderedTrackId) {
    lastRenderedTrackId = trackIdentifier;
    resetRenderedState();
  }

  const parsed = parseFormattedLine(targetPayload.active_line);
  const hasSegments = parsed.segments.length > 0;
  const sanitizedActiveLine = sanitizeText(targetPayload.active_line);
  const hasLineText = sanitizedActiveLine.length > 0;
  const hasRenderableLine = hasSegments || hasLineText;

  if (!hasRenderableLine) {
    if (!hasRenderedContent) {
      setLoadingState(true, DEFAULT_LINE);
    }
    return;
  }

  const plainForTitle = sanitizeText(parsed.plain);
  const baseLineText = plainForTitle.length
    ? plainForTitle
    : (hasLineText ? sanitizedActiveLine : DEFAULT_LINE);
  currentLineText = baseLineText.length ? baseLineText : DEFAULT_LINE;
  document.title = currentLineText;

  const segments = hasSegments
    ? parsed.segments
    : [produceTextSegment(currentLineText)];

  updateFontScale();
  renderSegments(segments);

  const translation = shouldShowTranslation(targetPayload)
    ? selectTranslation(parsed, targetPayload)
    : '';

  if (translation.length) {
    translationElement.textContent = translation;
    translationElement.style.display = 'block';
    translationElement.style.fontFamily = FONT_STACK;
  } else {
    translationElement.textContent = '';
    translationElement.style.display = 'none';
  }

  hasRenderedContent = true;
  queueResize();
  setLoadingState(false);
};

const registerExitShortcuts = (tauriCore) => {
  const handler = (event) => {
    const key = event.key?.toLowerCase();
    const comboPressed = event.metaKey || event.ctrlKey;
    const exitViaQ = comboPressed && key === 'q';
    const exitViaEsc = comboPressed && (key === 'escape' || key === 'esc');

    if (exitViaQ || exitViaEsc) {
      event.preventDefault();
      tauriCore.invoke('exit_app');
    }
  };

  window.addEventListener('keydown', handler);
};

const bootstrap = async () => {
  try {
    updateFontScale();
    window.addEventListener('resize', updateFontScale);

    activeLineElement.style.fontFamily = FONT_STACK;
    translationElement.style.fontFamily = FONT_STACK;

    setLoadingState(true, DEFAULT_LINE);

    const tauri = window.__TAURI__;
    if (!tauri || !tauri.core || !tauri.event) {
      console.error('未找到 Tauri API');
      render(null);
      return;
    }

    const { invoke } = tauri.core;
    const { listen } = tauri.event;

    if (windowResizer) {
      await windowResizer.init(tauri);
    }

    try {
      const payload = await invoke('get_lyrics_state');
      render(payload);
    } catch (initialError) {
      console.error('获取初始歌词状态失败:', initialError);
      render(null);
    }

    try {
      await listen('lyrics:update', ({ payload }) => {
        render(payload);
      });
    } catch (listenError) {
      console.error('监听歌词更新失败:', listenError);
    }

    registerExitShortcuts(tauri.core);
  } catch (error) {
    console.error('歌词渲染初始化失败:', error);
    render(null);
  }
};

bootstrap();
