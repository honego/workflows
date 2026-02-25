// @name         RFCShop 抢购推土机版 v6.5
// @namespace    http://tampermonkey.net
// @version      6.5.1
// @description  自动监控库存 填写优惠码 自动勾选条款 CF盾过绿后自动三重提交
// @author       iniwex & You & Gemini
// @match        *://my.rfchost.com/cart.php*
// @match        *://my.rfchost.com/index.php?rp=/store/*
// @grant        GM_notification
// @grant        window.focus

(function () {
  "use strict";

  // 核心配置区
  const SETTINGS = {
    refreshMs: 4000, // 刷新频率 4000毫秒 (4秒)
    billingCycle: "monthly", // 默认月付
    playAlarm: true, // 有货报警音
    autoSubmit: true, // 最后一步自动提交

    targetProducts: ["JP2-CO-Micro-Lite", "JP2-CO-Micro"],
    outOfStockWords: ["0 Available", "Out of Stock", "缺货"],
    promoCode: "我是高手我不需要发工单",
  };

  let isProcessingPromo = false;
  const audio = new Audio("https://actions.google.com/sounds/v1/alarms/beep_short.ogg");
  const url = window.location.href;
  const action = new URLSearchParams(window.location.search).get("a");

  console.log("🚀 RFCHOST 推土机 (正式发车版) 已挂载 | 状态: " + (action || "列表监控中"));

  if (url.includes("index.php?rp=/store/")) monitorStock();
  else if (action === "confproduct" || url.includes("a=add")) handleConfigPage();
  else if (action === "view") handleReviewPage();
  else if (action === "checkout") handleCheckoutPage();

  function monitorStock() {
    const packages = document.querySelectorAll("div.package");
    let found = false;
    for (let pkg of packages) {
      let titleElement = pkg.querySelector("h3.package-title");
      if (!titleElement) continue;
      let productName = titleElement.innerText.trim();
      if (SETTINGS.targetProducts.length === 0 || SETTINGS.targetProducts.some((name) => productName.includes(name))) {
        let qtyElement = pkg.querySelector(".package-qty");
        let buyBtn = pkg.querySelector("a.btn-order-now");
        if (
          !(qtyElement && qtyElement.innerText.includes(SETTINGS.outOfStockWords[0])) &&
          buyBtn &&
          !buyBtn.classList.contains("disabled")
        ) {
          GM_notification({ text: `发现 ${productName} 有货，冲刺！`, title: "抢购预警" });
          window.focus();
          buyBtn.click();
          return;
        }
      }
    }
    if (!found) setTimeout(() => location.reload(), SETTINGS.refreshMs + Math.floor(Math.random() * 1000));
  }

  function handleConfigPage() {
    if (document.body.innerText.includes("Out of Stock") || document.body.innerText.includes("缺货")) {
      setTimeout(() => location.reload(), SETTINGS.refreshMs);
      return;
    }
    if (SETTINGS.playAlarm) audio.play().catch(() => {});

    const cycleInput = document.querySelector(`input[name="billingcycle"][value="${SETTINGS.billingCycle}"]`);
    if (cycleInput && !cycleInput.checked) {
      if (typeof jQuery !== "undefined" && jQuery(cycleInput).iCheck) jQuery(cycleInput).iCheck("check");
      else cycleInput.click();
    }

    const configBtnTimer = setInterval(() => {
      const nextBtn =
        document.getElementById("btnCompleteProductConfigMob") ||
        document.querySelector('button[type="submit"].btn-checkout') ||
        document.querySelector("#btnCompleteProductConfig");
      if (nextBtn && !nextBtn.classList.contains("hidden")) {
        clearInterval(configBtnTimer);
        nextBtn.click();
      }
    }, 200);
  }

  function handleReviewPage() {
    const checkoutBtn = document.getElementById("checkout");
    if (checkoutBtn) checkoutBtn.click();
  }

  function handleCheckoutPage() {
    console.log("🔥 进入决战：处理优惠码、条款与令牌扫描...");

    const finalRunner = setInterval(() => {
      const promoInput = document.getElementById("inputPromotionCode") || document.getElementById("promocode");
      const validateBtn =
        document.querySelector('button[name="validatepromo"]') ||
        document.querySelector('button[value="Validate Code"]') ||
        Array.from(document.querySelectorAll("button")).find(
          (el) => el.innerText.includes("验证") || el.innerText.includes("Validate"),
        );

      // 填优惠码
      const promoApplied =
        document.body.innerText.includes("移除") ||
        document.body.innerText.includes("Promocode Accepted") ||
        document.body.innerText.includes("Remove");
      if (SETTINGS.promoCode && promoInput && !promoApplied && !isProcessingPromo) {
        if (promoInput.value !== SETTINGS.promoCode) promoInput.value = SETTINGS.promoCode;
        if (validateBtn) {
          isProcessingPromo = true;
          validateBtn.click();
          setTimeout(() => {
            isProcessingPromo = false;
          }, 3000);
        }
      }

      // 暴力勾选服务条款
      const realTOS = document.querySelector("input[data-tos-checkbox]") || document.getElementById("accepttos");
      if (realTOS && !realTOS.checked) {
        if (typeof jQuery !== "undefined" && jQuery(realTOS).iCheck) {
          jQuery(realTOS).iCheck("check");
        } else {
          const helper = realTOS.nextElementSibling;
          if (helper && helper.classList.contains("iCheck-helper")) helper.click();
          else {
            const label = realTOS.closest("label");
            if (label) label.click();
            else realTOS.click();
          }
        }
        realTOS.checked = true;
      }

      // 暴力扫描长令牌
      let hasValidToken = false;
      let tokenInputFound = false;
      const cfInputs = document.querySelectorAll(
        'input[name="cf-turnstile-response"], input[name="g-recaptcha-response"]',
      );

      if (cfInputs.length > 0) {
        tokenInputFound = true;
        hasValidToken = cfInputs[0].value.length > 20;
      } else {
        const hiddenInputs = document.querySelectorAll('input[type="hidden"]');
        for (let input of hiddenInputs) {
          if (input.value && input.value.length > 100) {
            hasValidToken = true;
            break;
          }
        }
      }

      const isPromoReady = !SETTINGS.promoCode || promoApplied;
      const isTosReady = !realTOS || realTOS.checked;
      const isTokenReady = tokenInputFound
        ? hasValidToken
        : hasValidToken || document.querySelectorAll("iframe").length === 0;

      console.log(
        `后台雷达 -> 优惠码:${isPromoReady ? "✅" : "⏳"} | 条款:${isTosReady ? "✅" : "⏳"} | CF盾令牌:${isTokenReady ? "✅" : "⚠️等您手动点击"}`,
      );

      if (isPromoReady && isTosReady && isTokenReady && SETTINGS.autoSubmit) {
        console.log("🚀 破门而入！令牌已截获，执行强制提交！");
        clearInterval(finalRunner);

        const checkoutBtn = document.getElementById("checkout");

        // 强行突破任何前端限制
        if (checkoutBtn) {
          checkoutBtn.click();
          setTimeout(() => {
            if (typeof jQuery !== "undefined") jQuery("#checkout").trigger("click");
          }, 100);
        }

        setTimeout(() => {
          const form = document.getElementById("frmCheckout") || document.querySelector('form[action*="checkout"]');
          if (form && !document.body.innerText.includes("Please wait")) {
            console.log("执行底层表单提交...");
            form.submit();
          }
        }, 500);

        GM_notification({ text: `订单冲刺完毕！请等待账单跳转并扫码付款！`, title: "抢购成功" });
      }
    }, 1000);
  }
})();
