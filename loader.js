/* The unchanged Godot game is loaded through its public Engine API. */
(() => {
  'use strict';
  const $ = (id) => document.getElementById(id);
  const nativeFetch = window.fetch.bind(window);
  const isTouch = new URLSearchParams(location.search).get('touch') === '1' || (navigator.maxTouchPoints > 0 && matchMedia('(pointer: coarse)').matches);
  const cacheName = 'souplife-game-chunks-v1';
  let cache = null;
  let manifest;
  let engine;
  let started = false;
  let allowPortrait = false;
  let byteProgress = new Map();
  let lastProgressPaint = 0;
  let phase = 'download';
  const resourceRequests = new Map();

  function paintProgress(force = false) {
    if (!manifest || phase !== 'download') return;
    if (!force && performance.now() - lastProgressPaint < 80) return;
    lastProgressPaint = performance.now();
    const bytes = [...byteProgress.values()].reduce((sum, value) => sum + value, 0);
    const percent = Math.min(92, Math.round(bytes / manifest.downloadBytes * 92));
    $('progress').value = percent;
    $('percent').textContent = `${percent}%`;
    $('status').textContent = bytes ? '正在装好食材和行囊…' : '正在准备餐车…';
  }

  function fail(error) {
    console.error('[Souplife web]', error);
    $('welcome').hidden = false;
    $('loading').hidden = true;
    $('play').hidden = true;
    $('error').hidden = false;
    $('error').textContent = error.userMessage || '餐车暂时没能启动。请检查网络后重新加载；如果是在微信内打开，可以试试“在浏览器打开”。';
    $('retry').hidden = false;
    $('rotate').hidden = true;
  }

  function userError(message) {
    const error = new Error(message);
    error.userMessage = message;
    return error;
  }

  async function decompress(bytes, expectedSize) {
    let raw;
    if (window.DecompressionStream) {
      const reader = new Response(bytes).body.pipeThrough(new DecompressionStream('gzip'));
      raw = new Uint8Array(await new Response(reader).arrayBuffer());
    } else {
      // Older WeChat/X5 browsers still support Godot but lack the native gzip API.
      // The same-origin fallback processes one verified block at a time (max 8 MiB).
      raw = window.fflate.gunzipSync(bytes, { out: new Uint8Array(expectedSize) });
    }
    if (raw.byteLength !== expectedSize) throw new Error('Incomplete game resource');
    return raw;
  }

  async function compressedChunk(chunk) {
    const absolute = new URL(chunk.url, location.href).href;
    for (let attempt = 0; attempt < 3; attempt++) {
      let timeout;
      let controller;
      function keepDownloadAlive() {
        clearTimeout(timeout);
        if (controller) timeout = setTimeout(() => controller.abort(), 45000);
      }
      try {
        let response = cache && await cache.match(absolute);
        const cached = !!response;
        if (!response) {
          controller = typeof AbortController === 'function' ? new AbortController() : null;
          // Limit silence, not total duration: a slow connection can keep making progress.
          keepDownloadAlive();
          response = await nativeFetch(absolute, { cache: 'force-cache', ...(controller ? { signal: controller.signal } : {}) });
        }
        if (!response.ok) throw new Error(`Resource download failed (${response.status})`);
        const result = new Uint8Array(chunk.bytes);
        const reader = response.body.getReader();
        let offset = 0;
        while (true) {
          const { value, done } = await reader.read();
          if (done) break;
          if (value.length) keepDownloadAlive();
          if (offset + value.length > result.length) throw new Error('Unexpected game resource size');
          result.set(value, offset);
          offset += value.length;
          byteProgress.set(chunk.url, offset);
          paintProgress();
        }
        clearTimeout(timeout);
        if (offset !== chunk.bytes) throw new Error('Incomplete game download');
        if (crypto.subtle) {
          const hashBytes = new Uint8Array(await crypto.subtle.digest('SHA-256', result));
          const hash = [...hashBytes].map((value) => value.toString(16).padStart(2, '0')).join('');
          if (hash !== chunk.sha256) throw new Error('Game resource verification failed');
        }
        if (!cached && cache) await cache.put(absolute, new Response(result)).catch(() => {});
        return result;
      } catch (error) {
        if (cache) await cache.delete(absolute).catch(() => {});
        byteProgress.set(chunk.url, 0);
        if (attempt === 2) throw error;
      } finally {
        clearTimeout(timeout);
      }
    }
  }

  async function prepareResources() {
    const chunks = new Map();
    for (const resource of Object.values(manifest.resources)) {
      let offset = 0;
      for (const chunk of resource.chunks) {
        if (chunk.offset !== offset || !Number.isSafeInteger(chunk.rawBytes) || chunk.rawBytes <= 0 || chunk.rawBytes > 8 * 1048576) {
          throw new Error('Invalid game resource layout');
        }
        offset += chunk.rawBytes;
        chunks.set(chunk.url, chunk);
      }
      if (offset !== resource.rawBytes) throw new Error('Invalid game resource length');
    }
    const queue = [...chunks.values()];
    let cursor = 0;
    async function worker() {
      while (cursor < queue.length) {
        await compressedChunk(queue[cursor++]);
      }
    }
    // Precache compressed blocks only. Never keep a full decompressed pack in JS.
    // There are two downloads total, rather than two for each of wasm and pck.
    await Promise.all([worker(), worker()]);
  }

  function streamedResponse(resource, contentType) {
    let cursor = 0;
    let produced = 0;
    let cancelled = false;
    const stream = new ReadableStream({
      async pull(controller) {
        try {
          if (cursor >= resource.chunks.length) {
            if (produced !== resource.rawBytes) throw new Error('Incomplete game stream');
            controller.close();
            return;
          }
          const chunk = resource.chunks[cursor++];
          const compressed = await compressedChunk(chunk);
          const raw = await decompress(compressed, chunk.rawBytes);
          if (cancelled) return;
          if (chunk.offset !== produced) throw new Error('Incorrect game stream offset');
          produced += raw.byteLength;
          controller.enqueue(raw);
        } catch (error) { controller.error(error); }
      },
      cancel() { cancelled = true; },
    });
    return new Response(stream, { headers: { 'Content-Type': contentType, 'Content-Length': String(resource.rawBytes) } });
  }

  function loadScript(url) {
    return new Promise((resolve, reject) => {
      const script = document.createElement('script');
      script.src = url;
      script.onload = resolve;
      script.onerror = () => reject(new Error('Unable to load game engine'));
      document.head.appendChild(script);
    });
  }

  function rotateHint() {
    $('rotate').hidden = !(started && isTouch && innerHeight > innerWidth && !allowPortrait);
  }

  async function fullscreen() {
    try {
      if (document.fullscreenElement) await document.exitFullscreen();
      else if (document.documentElement.requestFullscreen) await document.documentElement.requestFullscreen();
      if (isTouch && screen.orientation && screen.orientation.lock && document.fullscreenElement) {
        await screen.orientation.lock('landscape').catch(() => {});
      }
    } catch (_) { /* iOS browsers still support ordinary landscape play. */ }
    $('canvas').focus();
  }

  async function prepare() {
    if (!window.WebAssembly || !window.ReadableStream) throw userError('当前微信浏览器版本暂时不能运行游戏，请更新微信后重试。');
    if (!window.DecompressionStream) await loadScript('vendor/fflate-0.8.3.min.js');
    manifest = await nativeFetch('game-manifest.json', { cache: 'no-cache' }).then((response) => {
      if (!response.ok) throw new Error('Game manifest unavailable');
      return response.json();
    });
    $('download-note').textContent = `首次加载约 ${Math.ceil(manifest.downloadBytes / 1048576)} MB，已下载的资源会尽量缓存在本机。`;
    try { cache = await caches.open(cacheName); } catch (_) { /* Private browsing may disable CacheStorage. */ }
    await loadScript(`index.js?v=${manifest.version}`);
    const missing = Engine.getMissingFeatures({ threads: false });
    if (missing.length) throw userError('这个浏览器暂时不能运行游戏。请用支持 WebGL 2 的较新手机浏览器打开。');
    await prepareResources();
    paintProgress(true);
    phase = 'ready';
    resourceRequests.set(new URL('index.wasm', location.href).href,
      { resource: manifest.resources.wasm, contentType: 'application/wasm' });
    resourceRequests.set(new URL('index.pck', location.href).href,
      { resource: manifest.resources.pck, contentType: 'application/octet-stream' });
    engine = new Engine({
      canvas: $('canvas'), executable: 'index', mainPack: 'index.pck', canvasResizePolicy: 2,
      locale: 'zh_CN', focusCanvas: true, experimentalVK: false,
      fileSizes: { 'index.wasm': manifest.resources.wasm.rawBytes, 'index.pck': manifest.resources.pck.rawBytes },
      onExit: () => {
        started = false;
        $('welcome').hidden = false;
        $('loading').hidden = true;
        $('play').hidden = true;
        $('rotate').hidden = true;
        $('fullscreen').hidden = true;
        document.querySelector('.tagline').textContent = '进度已保存，下次继续这段旅程。';
        $('retry').hidden = false;
        $('retry').textContent = '重新进入游戏';
      },
      onPrint: (...args) => console.log(...args),
      onPrintError: (...args) => console.error(...args),
    });
    $('loading').hidden = true;
    $('play').hidden = false;
    $('play').focus({ preventScroll: true });
    document.documentElement.dataset.ready = 'true';
    if (cache) {
      const allowed = new Set(Object.values(manifest.resources).flatMap((r) => r.chunks.map((chunk) => new URL(chunk.url, location.href).href)));
      cache.keys().then((keys) => Promise.all(keys.filter((key) => !allowed.has(key.url)).map((key) => cache.delete(key)))).catch(() => {});
    }
  }

  $('play').addEventListener('click', async () => {
    if (started) return;
    $('play').disabled = true;
    $('play').textContent = '欢迎上车…';
    try {
      // Let the tap finish and paint feedback before Godot builds the initial scene.
      await new Promise((resolve) => requestAnimationFrame(() => setTimeout(resolve, 100)));
      // Keep Godot's standard startGame initialization and filesystem sequence.
      // Only its two binary requests are replaced with verified block streams.
      window.fetch = function (input, options) {
        const requested = new URL(typeof input === 'string' || input instanceof URL ? input : input.url, location.href).href;
        if (resourceRequests.has(requested)) {
          const entry = resourceRequests.get(requested);
          return Promise.resolve(streamedResponse(entry.resource, entry.contentType));
        }
        return nativeFetch(input, options);
      };
      try {
        await engine.startGame({ args: isTouch ? ['--', '--mobile-ui'] : [] });
      } finally {
        window.fetch = nativeFetch;
        resourceRequests.clear();
      }
      started = true;
      $('welcome').hidden = true;
      $('fullscreen').hidden = !document.documentElement.requestFullscreen;
      $('canvas').focus();
      document.documentElement.dataset.playing = 'true';
      rotateHint();
    } catch (error) { fail(error); }
  });
  $('retry').addEventListener('click', () => location.reload());
  $('fullscreen').addEventListener('click', fullscreen);
  $('portrait-continue').addEventListener('click', () => { allowPortrait = true; rotateHint(); });
  addEventListener('resize', rotateHint);
  addEventListener('contextmenu', (event) => event.preventDefault());
  addEventListener('unhandledrejection', (event) => { if (!started) fail(event.reason || new Error('Game initialization failed')); });
  prepare().catch(fail);
})();
