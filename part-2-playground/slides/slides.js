(() => {
  const slides = [...document.querySelectorAll(".slide")];
  const counter = document.getElementById("counter");
  let cur = 0;

  function show(i) {
    cur = Math.max(0, Math.min(slides.length - 1, i));
    slides.forEach((s, n) => s.classList.toggle("on", n === cur));
    counter.textContent = `${cur + 1} / ${slides.length}`;
    history.replaceState(null, "", `#${cur + 1}`);
  }

  // Prompts: filled from prompts.js, each with a copy button.
  document.querySelectorAll("pre.prompt").forEach((pre) => {
    const text = (window.PROMPTS || {})[pre.dataset.id] || "(prompt missing)";
    pre.textContent = text.trim();
    const box = document.createElement("div");
    box.className = "prompt-box";
    pre.replaceWith(box);
    const btn = document.createElement("button");
    btn.className = "copy";
    btn.textContent = "Copy";
    btn.addEventListener("click", async () => {
      try {
        await navigator.clipboard.writeText(text.trim());
      } catch (e) {
        const r = document.createRange();
        r.selectNodeContents(pre);
        const sel = getSelection();
        sel.removeAllRanges();
        sel.addRange(r);
        document.execCommand("copy");
      }
      btn.textContent = "Copied";
      btn.blur(); // so the arrow keys keep turning the slides
      setTimeout(() => (btn.textContent = "Copy"), 1500);
    });
    box.append(pre, btn);
  });

  // Command list: hover, focus or click shows the hint below the list.
  document.querySelectorAll(".cmds").forEach((list) => {
    const hint = list.parentElement.querySelector(".hint");
    list.querySelectorAll(".cmd").forEach((b) => {
      const set = () => {
        list.querySelectorAll(".cmd").forEach((o) => o.classList.toggle("on", o === b));
        hint.textContent = b.dataset.hint;
      };
      b.addEventListener("mouseenter", set);
      b.addEventListener("focus", set);
      b.addEventListener("click", () => {
        set();
        b.blur();
      });
    });
  });

  document.getElementById("prev").addEventListener("click", () => show(cur - 1));
  document.getElementById("next").addEventListener("click", () => show(cur + 1));
  document.addEventListener("keydown", (e) => {
    if (e.metaKey || e.ctrlKey || e.altKey) return;
    if ((e.key === " " || e.key === "Enter") && e.target.tagName === "BUTTON") return;
    if (["ArrowRight", "ArrowDown", "PageDown", " "].includes(e.key)) show(cur + 1);
    else if (["ArrowLeft", "ArrowUp", "PageUp"].includes(e.key)) show(cur - 1);
    else return;
    e.preventDefault();
  });
  window.addEventListener("hashchange", () => show(parseInt(location.hash.slice(1), 10) - 1 || 0));
  show(parseInt(location.hash.slice(1), 10) - 1 || 0);
})();
