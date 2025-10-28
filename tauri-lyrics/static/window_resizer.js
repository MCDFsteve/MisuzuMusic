export class WindowResizer {
  constructor(rootElement, options = {}) {
    this.rootElement = rootElement;
    this.invoke = null;
    this.resizeObserver = null;
    this.pendingFrame = null;
    this.lastWidth = 0;
    this.lastHeight = 0;
    const defaultPadding = { width: 24, height: 24 };
    this.padding = {
      width: options.padding?.width ?? defaultPadding.width,
      height: options.padding?.height ?? defaultPadding.height,
    };
    this.minSize = {
      width: options.minSize?.width ?? 160,
      height: options.minSize?.height ?? 120,
    };
    this.resizeOnWindowChange = this.scheduleResize.bind(this);
  }

  async init(tauri) {
    if (!this.rootElement || !tauri || !tauri.core || typeof tauri.core.invoke !== 'function') {
      console.warn('窗口自适应初始化失败：缺少 root 或 Tauri 接口');
      return false;
    }

    this.invoke = tauri.core.invoke;
    if (typeof ResizeObserver !== 'undefined') {
      this.resizeObserver = new ResizeObserver(() => this.scheduleResize());
      this.resizeObserver.observe(this.rootElement);
    }
    window.addEventListener('resize', this.resizeOnWindowChange, { passive: true });
    this.scheduleResize();
    return true;
  }

  scheduleResize() {
    if (!this.invoke) {
      return;
    }
    if (this.pendingFrame !== null) {
      cancelAnimationFrame(this.pendingFrame);
    }
    this.pendingFrame = requestAnimationFrame(() => {
      this.pendingFrame = null;
      void this.resizeToContent();
    });
  }

  async resizeToContent() {
    if (!this.invoke || !this.rootElement) {
      return;
    }

    const rect = this.rootElement.getBoundingClientRect();
    let contentWidth = rect.width + this.padding.width;
    let contentHeight = rect.height + this.padding.height;

    if (!Number.isFinite(contentWidth) || !Number.isFinite(contentHeight)) {
      return;
    }

    contentWidth = Math.max(contentWidth, this.minSize.width);
    contentHeight = Math.max(contentHeight, this.minSize.height);

    const scale = window.devicePixelRatio || 1;
    const physicalWidth = Math.max(1, Math.round(contentWidth * scale));
    const physicalHeight = Math.max(1, Math.round(contentHeight * scale));

    if (physicalWidth === this.lastWidth && physicalHeight === this.lastHeight) {
      return;
    }

    this.lastWidth = physicalWidth;
    this.lastHeight = physicalHeight;

    try {
      await this.invoke('resize_window', {
        width: physicalWidth,
        height: physicalHeight,
      });
    } catch (error) {
      console.error('调整桌面歌词窗口大小失败:', error);
    }
  }

  dispose() {
    if (this.resizeObserver) {
      this.resizeObserver.disconnect();
      this.resizeObserver = null;
    }
    window.removeEventListener('resize', this.resizeOnWindowChange);
    if (this.pendingFrame !== null) {
      cancelAnimationFrame(this.pendingFrame);
      this.pendingFrame = null;
    }
  }
}
