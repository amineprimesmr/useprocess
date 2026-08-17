(function () {
  function isValid(id) {
    return id && id.length >= 8 && id.indexOf("YOUR_") !== 0;
  }

  if (window.$crisp) return;

  fetch("/crisp-website-id.json", { cache: "no-store" })
    .then(function (res) {
      return res.ok ? res.json() : {};
    })
    .then(function (data) {
      var id = String((data && data.websiteID) || "").trim();
      if (!isValid(id) || window.$crisp) return;
      window.$crisp = [];
      window.CRISP_WEBSITE_ID = id;
      window.$crisp.push(["set", "session:segments", [["website"]]]);
      var s = document.createElement("script");
      s.src = "https://client.crisp.chat/l.js";
      s.async = true;
      document.head.appendChild(s);
    })
    .catch(function () {});
})();
