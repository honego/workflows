// 远程图片源配置
const IMAGE_SOURCES = [
  {
    name: "xxapi",
    url: "https://v2.xxapi.cn/api/heisi?return=302",
    referer: "https://v2.xxapi.cn/",
  },
  {
    name: "tzjsy",
    url: "https://pt.tzjsy.cn/hs/img.php",
    referer: "https://pt.tzjsy.cn/",
  },
];

// 单个图片源的最长等待时间
const IMAGE_TIMEOUT_MS = 8000;

// 首页 HTML
const html = `<!doctype html>
<html lang="zh-CN">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0, viewport-fit=cover" />
    <title>随机黑丝图片</title>
    <link
      rel="icon"
      type="image/png"
      href="https://m.360buyimg.com/i/jfs/t1/343134/32/18184/15071/68ff3492F23f6841a/7f13cf100e65096d.png"
    />
    <script
      defer
      src="https://umami.honeok.com/script.js"
      data-website-id="825b987b-6add-4b6a-b55d-c1cf19cd2690"
    ></script>
    <style>
      * {
        box-sizing: border-box;
      }

      html,
      body {
        min-height: 100%;
      }

      html {
        background: #121212;
      }

      body {
        background-color: #121212;
        color: #ffffff;
        font-family: "Microsoft YaHei", sans-serif;
        margin: 0;
        padding: 0;
        overflow-x: hidden;
        -webkit-font-smoothing: antialiased;
      }

      .container {
        width: min(95vw, 800px);
        min-height: 100dvh;
        margin: 0 auto;
        padding: 20px 0 calc(96px + env(safe-area-inset-bottom));
        text-align: center;
      }

      h1 {
        margin: 0 0 14px;
        font-size: 24px;
        line-height: 1.3;
        text-align: center;
      }

      .image-stage {
        display: flex;
        align-items: center;
        justify-content: center;
        width: 100%;
        height: min(768px, calc(100svh - 156px));
        height: min(768px, calc(100dvh - 156px));
        min-height: 420px;
        border-radius: 10px;
        background: #0f0f0f;
        box-shadow: 0 0 24px rgba(255, 255, 255, 0.18);
        overflow: hidden;
      }

      img {
        display: block;
        width: 100%;
        height: 100%;
        object-fit: contain;
        object-position: center;
        transition: opacity 0.2s ease;
      }

      .actions {
        position: fixed;
        left: 0;
        right: 0;
        bottom: max(16px, env(safe-area-inset-bottom));
        z-index: 10;
        display: flex;
        justify-content: center;
        padding: 0 16px;
        pointer-events: none;
      }

      .actions button {
        min-width: 96px;
        background-color: #333;
        color: #fff;
        border: none;
        padding: 12px 24px;
        font-size: 16px;
        line-height: 1.2;
        border-radius: 8px;
        cursor: pointer;
        box-shadow: 0 8px 24px rgba(0, 0, 0, 0.35);
        -webkit-tap-highlight-color: transparent;
        touch-action: manipulation;
        transition:
          background-color 0.2s ease,
          transform 0.2s ease,
          opacity 0.2s ease;
        pointer-events: auto;
      }

      .actions button:hover {
        background-color: #555;
        transform: translateY(-1px);
      }

      .actions button:disabled {
        cursor: wait;
        opacity: 0.72;
        transform: none;
      }

      .tips {
        min-height: 18px;
        color: #aaa;
        font-size: 13px;
        margin-top: 10px;
      }

      @media (max-width: 600px) {
        body {
          min-height: 100svh;
          min-height: 100dvh;
        }

        .container {
          width: 100vw;
          min-height: 100svh;
          min-height: 100dvh;
          display: flex;
          flex-direction: column;
          align-items: center;
          padding: max(12px, env(safe-area-inset-top)) 12px calc(92px + env(safe-area-inset-bottom));
        }

        h1 {
          flex: 0 0 auto;
          margin: 0 0 10px;
          font-size: clamp(20px, 5.4vw, 24px);
          line-height: 1.2;
          text-shadow: 0 2px 12px rgba(0, 0, 0, 0.45);
        }

        .image-stage {
          width: 100%;
          flex: 1 1 auto;
          height: min(72svh, calc(100svh - 138px));
          height: min(72dvh, calc(100dvh - 138px));
          min-height: min(360px, calc(100svh - 138px));
          min-height: min(360px, calc(100dvh - 138px));
          border-radius: 12px;
          box-shadow: 0 0 18px rgba(255, 255, 255, 0.14);
        }

        img {
          height: 100%;
        }

        .tips {
          flex: 0 0 auto;
          min-height: 16px;
          margin-top: 8px;
          font-size: 12px;
        }

        .actions {
          bottom: max(14px, env(safe-area-inset-bottom));
          padding: 0 18px;
        }

        .actions button {
          width: min(100%, 240px);
          min-height: 48px;
          padding: 13px 24px;
          font-size: 16px;
          border-radius: 10px;
          background-color: rgba(51, 51, 51, 0.96);
          box-shadow: 0 10px 28px rgba(0, 0, 0, 0.42);
        }
      }

      @media (max-width: 600px) and (orientation: landscape) {
        .container {
          width: min(100vw, 720px);
          padding: 8px 12px calc(72px + env(safe-area-inset-bottom));
        }

        h1 {
          font-size: 18px;
          margin-bottom: 6px;
        }

        .image-stage {
          height: calc(100svh - 92px);
          height: calc(100dvh - 92px);
          min-height: 220px;
        }

        .tips {
          display: none;
        }

        .actions {
          bottom: max(8px, env(safe-area-inset-bottom));
        }

        .actions button {
          min-height: 42px;
          width: 168px;
          padding: 10px 20px;
        }
      }

      @media (hover: none) {
        .actions button:hover {
          background-color: #333;
          transform: none;
        }
      }
    </style>
  </head>

  <body>
    <main class="container">
      <h1>随机黑丝图片</h1>

      <div class="image-stage">
        <img
          id="randomImage"
          src="data:image/gif;base64,R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7"
          alt="随机图片"
        />
      </div>

      <div class="tips" id="statusText"></div>
    </main>

    <div class="actions">
      <button id="nextBtn" type="button">下一张</button>
    </div>

    <script>
      const image = document.getElementById("randomImage");
      const nextBtn = document.getElementById("nextBtn");
      const statusText = document.getElementById("statusText");

      const PREFETCH_SIZE = 2;

      let currentObjectUrl = "";

      const readyImages = [];

      let pendingPrefetches = 0;
      let isLoading = false;

      function apiUrl() {
        return "/image?t=" + Date.now() + "&r=" + Math.random().toString(36).slice(2);
      }

      function setLoading(loading) {
        const needsWait = loading && readyImages.length === 0;
        nextBtn.disabled = needsWait;
        nextBtn.textContent = needsWait ? "加载中..." : "下一张";
        image.style.opacity = needsWait ? "0.55" : "1";
      }

      async function fetchImageBlob() {
        const response = await fetch(apiUrl(), {
          cache: "no-store",
          headers: {
            Accept: "image/avif,image/webp,image/apng,image/svg+xml,image/*,*/*;q=0.8",
          },
        });

        if (!response.ok) {
          throw new Error("图片加载失败");
        }

        return response.blob();
      }

      async function prefetchOne() {
        pendingPrefetches += 1;

        try {
          const blob = await fetchImageBlob();
          readyImages.push(URL.createObjectURL(blob));
        } catch (error) {
          console.error(error);
        } finally {
          pendingPrefetches -= 1;
          fillPrefetchQueue();
        }
      }

      function fillPrefetchQueue() {
        while (readyImages.length + pendingPrefetches < PREFETCH_SIZE) {
          prefetchOne();
        }
      }

      function showObjectUrl(nextObjectUrl) {
        const oldObjectUrl = currentObjectUrl;

        image.onload = function () {
          if (oldObjectUrl) {
            URL.revokeObjectURL(oldObjectUrl);
          }
        };

        image.onerror = function () {
          statusText.textContent = "图片加载失败，请重试";
        };

        currentObjectUrl = nextObjectUrl;
        image.src = nextObjectUrl;
      }

      async function loadImage() {
        if (isLoading) {
          return;
        }

        isLoading = true;
        statusText.textContent = "";
        setLoading(true);

        try {
          if (readyImages.length === 0) {
            const blob = await fetchImageBlob();
            readyImages.push(URL.createObjectURL(blob));
          }

          showObjectUrl(readyImages.shift());
        } catch (error) {
          console.error(error);
          statusText.textContent = "图片加载失败，请重试";
        } finally {
          isLoading = false;
          setLoading(false);
          fillPrefetchQueue();
        }
      }

      nextBtn.addEventListener("click", loadImage);

      window.addEventListener("load", function () {
        loadImage();
      });
    </script>
  </body>
</html>`;

// 给远程图片接口追加随机参数 减少缓存命中旧图的概率
function withCacheBuster(rawUrl) {
  const url = new URL(rawUrl);
  url.searchParams.set("_t", Date.now().toString());
  url.searchParams.set("_r", crypto.randomUUID());
  return url.toString();
}

// 请求单个图片源
async function fetchFromSource(source, signal) {
  const response = await fetch(withCacheBuster(source.url), {
    redirect: "follow",
    signal,
    headers: {
      Accept: "image/avif,image/webp,image/apng,image/svg+xml,image/*,*/*;q=0.8",
      Referer: source.referer,
      "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/120.0.0.0 Safari/537.36",
    },
    cf: {
      cacheTtl: 0,
      cacheEverything: false,
    },
  });

  if (!response.ok) {
    throw new Error(`${source.name} 返回异常：${response.status}`);
  }

  const contentType = response.headers.get("content-type") || "";

  if (contentType && !contentType.startsWith("image/") && contentType !== "application/octet-stream") {
    throw new Error(`${source.name} 没有返回图片`);
  }

  return {
    source,
    response,
  };
}

// 同时请求所有图片源 优先使用第一个成功返回图片头的响应
async function fetchFastestImage() {
  const controllers = IMAGE_SOURCES.map(() => new AbortController());
  const timeoutIds = controllers.map((controller) => setTimeout(() => controller.abort("timeout"), IMAGE_TIMEOUT_MS));

  const tasks = IMAGE_SOURCES.map((source, index) =>
    fetchFromSource(source, controllers[index].signal).then((result) => ({
      ...result,
      index,
    })),
  );

  try {
    const winner = await Promise.any(tasks);

    // 已经拿到最快可用图片后 中止其他较慢的远程请求
    controllers.forEach((controller, index) => {
      if (index !== winner.index) {
        controller.abort("winner-selected");
      }
    });

    return winner;
  } finally {
    timeoutIds.forEach((timeoutId) => clearTimeout(timeoutId));
  }
}

// 返回图片代理响应
async function imageResponse() {
  try {
    const { source, response } = await fetchFastestImage();

    return new Response(response.body, {
      status: 200,
      headers: {
        "content-type": response.headers.get("content-type") || "image/jpeg",
        "cache-control": "no-store, no-cache, must-revalidate, max-age=0",
        "access-control-allow-origin": "*",
        "x-image-source": source.name,
      },
    });
  } catch (error) {
    console.error(error);

    return new Response("图片请求失败，请稍后重试", {
      status: 502,
      headers: {
        "content-type": "text/plain; charset=utf-8",
        "cache-control": "no-store",
      },
    });
  }
}

// 返回首页
function pageResponse() {
  return new Response(html, {
    status: 200,
    headers: {
      "content-type": "text/html; charset=UTF-8",
      "cache-control": "no-store",
    },
  });
}

// Worker 入口
export default {
  async fetch(request) {
    const url = new URL(request.url);

    // 图片代理接口
    if (url.pathname === "/image") {
      return imageResponse();
    }

    // 主页
    return pageResponse();
  },
};
