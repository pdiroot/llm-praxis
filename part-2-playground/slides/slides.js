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

  async function writeClipboard(pre, text) {
    try {
      await navigator.clipboard.writeText(text);
    } catch (e) {
      const r = document.createRange();
      r.selectNodeContents(pre);
      const sel = getSelection();
      sel.removeAllRanges();
      sel.addRange(r);
      document.execCommand("copy");
    }
  }

  function copyButton(pre) {
    const btn = document.createElement("button");
    btn.className = "copy";
    btn.textContent = "Copy";

    btn.addEventListener("click", async () => {
      await writeClipboard(pre, pre.textContent);
      btn.textContent = "Copied";
      btn.classList.add("done");
      btn.blur(); // so the arrow keys keep turning the slides
      setTimeout(() => {
        btn.textContent = "Copy";
        btn.classList.remove("done");
      }, 1500);
    });

    return btn;
  }

  // Wrap a line to type: the sigil, the text and the copy button.
  function addLine(pre, sigil) {
    const line = document.createElement("div");
    line.className = pre.classList.contains("prompt") ? "line prompt-line" : "line";
    line.dataset.sigil = sigil;
    pre.replaceWith(line);
    line.append(pre, copyButton(pre));
  }

  function fillPrompt(pre) {
    pre.textContent = ((window.PROMPTS || {})[pre.dataset.id] || "(prompt missing)").trim();
  }

  // Put the window frame around the content of a terminal.
  function frame(term) {
    const body = document.createElement("div");
    body.className = "term-body";
    body.append(...term.childNodes);

    const bar = document.createElement("div");
    bar.className = "term-bar";
    bar.innerHTML = "<i></i><i></i><i></i><span></span>";
    const title = term.dataset.title || "claude";
    bar.querySelector("span").textContent = title[0].toUpperCase() + title.slice(1);

    term.append(bar, body);
  }

  document.querySelectorAll("pre.prompt").forEach(fillPrompt);
  document.querySelectorAll("pre.cmd, pre.prompt").forEach((pre) => {
    addLine(pre, "sh" in pre.dataset ? "$" : pre.dataset.sigil ?? ">");
  });
  document.querySelectorAll(".term").forEach(frame);

  // Navigation: the buttons, the keys and the #n in the URL.
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
