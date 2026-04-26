export default {
  async fetch(request) {
    const url = new URL(request.url);

    // 图片代理接口：前端访问同域 /image，Worker 再去拉取远程图片
    if (url.pathname === "/image") {
      const imageUrl = `https://pt.tzjsy.cn/hs/img.php?t=${Date.now()}`;

      try {
        const res = await fetch(imageUrl, {
          headers: {
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
            Referer: "https://pt.tzjsy.cn/",
          },
        });

        if (!res.ok) {
          return new Response("图片加载失败", { status: 502 });
        }

        return new Response(res.body, {
          status: 200,
          headers: {
            "Content-Type": res.headers.get("Content-Type") || "image/jpeg",
            "Cache-Control": "no-store, no-cache, must-revalidate",
            "Access-Control-Allow-Origin": "*",
          },
        });
      } catch (err) {
        return new Response("图片请求异常", { status: 500 });
      }
    }

    // 主页
    return new Response(html, {
      status: 200,
      headers: {
        "Content-Type": "text/html; charset=UTF-8",
        "Cache-Control": "no-store",
      },
    });
  },
};

const html = `<!doctype html>
<html lang="zh-CN">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>随机黑丝图片</title>
    <link
      rel="icon"
      type="image/png"
      href="https://m.360buyimg.com/i/jfs/t1/343134/32/18184/15071/68ff3492F23f6841a/7f13cf100e65096d.png"
    />
    <style>
      body {
        background-color: #121212;
        color: #ffffff;
        font-family: "Microsoft YaHei", sans-serif;
        margin: 0;
        padding: 0;
        display: flex;
        flex-direction: column;
        align-items: center;
        justify-content: flex-start;
        min-height: 100vh;
      }

      h1 {
        margin-top: 30px;
        font-size: 24px;
        text-align: center;
      }

      .container {
        width: 95%;
        max-width: 800px;
        padding: 20px;
        text-align: center;
      }

      img {
        width: 100%;
        max-height: 80vh;
        object-fit: contain;
        border-radius: 10px;
        box-shadow: 0 0 20px rgba(255, 255, 255, 0.2);
        margin-bottom: 20px;
        transition: opacity 0.3s ease;
      }

      .buttons {
        display: flex;
        justify-content: center;
      }

      .buttons button {
        background-color: #333;
        color: #fff;
        border: none;
        padding: 12px 24px;
        font-size: 16px;
        border-radius: 8px;
        cursor: pointer;
        transition:
          background-color 0.3s ease,
          transform 0.2s ease;
      }

      .buttons button:hover {
        background-color: #555;
        transform: scale(1.05);
      }

      .tips {
        color: #aaa;
        font-size: 13px;
        margin-top: 8px;
      }

      @media (max-width: 600px) {
        h1 {
          font-size: 20px;
        }

        .buttons button {
          width: 100%;
          font-size: 16px;
        }
      }
    </style>
  </head>

  <body>
    <div class="container">
      <h1>随机黑丝图片</h1>

      <img
        id="randomImage"
        src="data:image/gif;base64,R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7"
        alt="随机图片"
      />

      <div class="buttons">
        <button id="nextBtn" onclick="loadImage()">下一张</button>
      </div>

      <div class="tips" id="statusText"></div>
    </div>

    <script>
      const image = document.getElementById("randomImage");
      const nextBtn = document.getElementById("nextBtn");
      const statusText = document.getElementById("statusText");

      let preloader = new Image();
      let isPrefetched = false;

      function apiUrl() {
        return "/image?t=" + Date.now() + "&r=" + Math.random();
      }

      function setLoading(loading) {
        nextBtn.disabled = loading;
        nextBtn.textContent = loading ? "加载中..." : "下一张";
        image.style.opacity = loading ? "0.5" : "1";
      }

      function prefetchNextImage() {
        isPrefetched = false;
        preloader = new Image();

        preloader.onload = function () {
          isPrefetched = true;
        };

        preloader.onerror = function () {
          isPrefetched = false;
        };

        preloader.src = apiUrl();
      }

      function loadImage() {
        statusText.textContent = "";
        setLoading(true);

        if (isPrefetched) {
          image.onload = function () {
            setLoading(false);
          };

          image.onerror = function () {
            setLoading(false);
            statusText.textContent = "图片加载失败，请重试";
          };

          image.src = preloader.src;
          prefetchNextImage();
          return;
        }

        const currentImageUrl = apiUrl();
        const currentLoader = new Image();

        currentLoader.onload = function () {
          image.src = currentImageUrl;
          setLoading(false);
          prefetchNextImage();
        };

        currentLoader.onerror = function () {
          setLoading(false);
          statusText.textContent = "图片加载失败，请重试";
          prefetchNextImage();
        };

        currentLoader.src = currentImageUrl;
      }

      window.onload = loadImage;
    </script>
  </body>
</html>`;
