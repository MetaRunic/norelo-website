/* =====================================================================
   Armoires Tremblay - app.js
   1) Loads content.json
   2) Resolves the active locale (?lang= or saved or default)
   3) Binds text/attributes & renders dynamic lists from the data
   4) Hero: interactive Three.js kitchen-island scene (WebGL)
            with a graceful video/image fallback
   5) UI behaviour: sticky header, mobile nav, reveal-on-scroll, form
   --------------------------------------------------------------------
   CONTENT BINDING CONVENTIONS (used in index.html)
     data-text="path"               -> element.textContent
     data-attr="attr:path,attr:path"-> sets one or more attributes
     data-list="path"               -> container filled by a renderer
     data-options="path"            -> <select> options from an array
   Paths are dotted and resolve against the merged context:
     { ...locale, meta, assets }     e.g. "hero.title", "meta.brand"
   ===================================================================== */
(() => {
  "use strict";

  const CONTENT_URL = "content.json";

  /* ---------- small helpers ---------- */
  const $  = (sel, root = document) => root.querySelector(sel);
  const $$ = (sel, root = document) => Array.from(root.querySelectorAll(sel));

  const get = (obj, path) =>
    path.split(".").reduce((acc, key) => (acc == null ? acc : acc[key]), obj);

  const el = (tag, attrs = {}, children = []) => {
    const node = document.createElement(tag);
    for (const [k, v] of Object.entries(attrs)) {
      if (v == null || v === false) continue;
      if (k === "class") node.className = v;
      else if (k === "text") node.textContent = v;
      else if (k === "html") node.innerHTML = v;
      else node.setAttribute(k, v);
    }
    (Array.isArray(children) ? children : [children]).forEach((c) => {
      if (c == null) return;
      node.appendChild(typeof c === "string" ? document.createTextNode(c) : c);
    });
    return node;
  };

  const icon = (id) => {
    const svg = document.createElementNS("http://www.w3.org/2000/svg", "svg");
    const use = document.createElementNS("http://www.w3.org/2000/svg", "use");
    use.setAttribute("href", "#ic-" + id);
    svg.appendChild(use);
    return svg;
  };

  const safeStore = {
    get(k) { try { return localStorage.getItem(k); } catch { return null; } },
    set(k, v) { try { localStorage.setItem(k, v); } catch { /* no-op */ } },
  };

  const clamp = (v, a, b) => Math.min(Math.max(v, a), b);
  const lerp = (a, b, t) => a + (b - a) * t;
  const easeOutCubic = (t) => 1 - Math.pow(1 - t, 3);
  const easeInOut = (t) => (t < 0.5 ? 2 * t * t : 1 - Math.pow(-2 * t + 2, 2) / 2);
  const prefersReduced = () => matchMedia("(prefers-reduced-motion: reduce)").matches;
  const slug = (x) => (x || "").toLowerCase()
    .replace(/[àâä]/g, "a").replace(/[éèêë]/g, "e").replace(/[îï]/g, "i")
    .replace(/[ôö]/g, "o").replace(/[ûü]/g, "u").replace(/ç/g, "c")
    .replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "");

  /* ---------- bootstrap ---------- */
  document.addEventListener("DOMContentLoaded", init);

  async function init() {
    let data;
    try {
      const res = await fetch(CONTENT_URL, { cache: "no-cache" });
      if (!res.ok) throw new Error("HTTP " + res.status);
      data = await res.json();
    } catch (err) {
      console.error("[Armoires Tremblay] Impossible de charger content.json:", err);
      showLoadError();
      return;
    }

    const lang = resolveLocale(data);
    const locale = data.locales[lang];
    const ctx = Object.assign({}, locale, { meta: data.meta, assets: data.assets });

    document.documentElement.lang = (locale.html && locale.html.lang) || lang;

    bindText(ctx);
    bindAttrs(ctx);
    bindSelectOptions(ctx);
    renderLists(ctx);

    initHeader();
    initMobileNav();
    initReveal();
    const gallery = await buildGallery(ctx);
    initShowcaseFilter(ctx);
    initLightbox(gallery);
    initHero(ctx);
    setFooterYear();
    initRouter();
    initCareers();
  }

  /* ---------- careers view: hash router + accordions ---------- */
  function initRouter() {
    const home = $("#view-home");
    const careers = $("#view-careers");
    if (!careers) return;
    let first = true;
    const apply = () => {
      const isCareers = location.hash === "#carrieres";
      const active = isCareers ? careers : home;
      const inactive = isCareers ? home : careers;
      if (inactive) inactive.hidden = true;
      if (active) {
        active.hidden = false;
        if (!first) {
          active.classList.remove("is-entering");
          void active.offsetWidth;          /* restart the fade */
          active.classList.add("is-entering");
        }
      }
      if (isCareers || location.hash === "#top" || !location.hash) {
        window.scrollTo({ top: 0, behavior: first ? "auto" : "smooth" });
      } else {
        const t = document.querySelector(location.hash);
        if (t) requestAnimationFrame(() => t.scrollIntoView({ behavior: "smooth", block: "start" }));
      }
      first = false;
    };
    window.addEventListener("hashchange", apply);
    apply();
  }

  function initCareers() {
    const view = $("#view-careers");
    if (!view) return;
    $$(".career__head", view).forEach((btn) => {
      btn.addEventListener("click", () => {
        const item = btn.closest(".career");
        const open = item.classList.toggle("is-open");
        btn.setAttribute("aria-expanded", String(open));
      });
    });

    /* "Postuler" -> jump to the form and preselect the matching poste */
    const posteSelect = $("#apply-poste");
    const applyBlock = $("#careers-apply");
    $$(".career__apply", view).forEach((btn) => {
      btn.addEventListener("click", () => {
        const poste = btn.getAttribute("data-poste") || "";
        if (posteSelect) posteSelect.value = poste;
        if (applyBlock) applyBlock.scrollIntoView({ behavior: "smooth", block: "start" });
      });
    });

    /* application form -> compose an email (static site, no backend) */
    const form = $("#apply-form");
    if (form) {
      form.addEventListener("submit", (e) => {
        e.preventDefault();
        const val = (id) => { const n = $(id); return n ? n.value.trim() : ""; };
        const subject = encodeURIComponent("Candidature - " + val("#apply-poste"));
        const body = encodeURIComponent(
          "Nom complet : " + val("#apply-nom") +
          "\nTéléphone : " + val("#apply-tel") +
          "\nCourriel : " + val("#apply-courriel") +
          "\nPoste : " + val("#apply-poste") +
          "\n\n(N'oubliez pas de joindre votre CV a ce courriel.)"
        );
        window.location.href = "mailto:rh@armoirestremblay.com?subject=" + subject + "&body=" + body;
      });
    }
  }

  /* ---------- locale ---------- */
  function resolveLocale(data) {
    const param = new URLSearchParams(location.search).get("lang");
    const saved = safeStore.get("at-lang");
    const candidate = param || saved;
    const lang = candidate && data.locales[candidate] ? candidate : data.meta.defaultLocale;
    if (param) safeStore.set("at-lang", lang);
    return lang;
  }

  /* ---------- text & attribute binding ---------- */
  function bindText(ctx) {
    $$("[data-text]").forEach((node) => {
      const val = get(ctx, node.dataset.text);
      if (val != null) node.textContent = val;
    });
  }

  function bindAttrs(ctx) {
    $$("[data-attr]").forEach((node) => {
      node.dataset.attr.split(",").forEach((pair) => {
        const [attr, path] = pair.split(":").map((s) => s.trim());
        const val = get(ctx, path);
        if (attr && val != null) node.setAttribute(attr, val);
      });
    });
  }

  function bindSelectOptions(ctx) {
    $$("[data-options]").forEach((sel) => {
      const opts = get(ctx, sel.dataset.options);
      if (!Array.isArray(opts)) return;
      sel.appendChild(el("option", { value: "", text: "Sélectionner une option" }));
      opts.forEach((o) => sel.appendChild(el("option", { value: o, text: o })));
    });
  }

  /* ---------- list renderers (dispatch by container id) ---------- */
  function renderLists(ctx) {
    const renderers = {
      "nav-links": renderNavLinks,
      "mobile-nav-links": renderNavLinks,
      "approche-pillars": renderPillars,
      "categories-grid": renderCategories,
      "testimonials-grid": renderTestimonials,
      "contact-details": renderContactDetails,
      "contact-assurances": renderAssurances,
      "footer-cols": renderFooterCols,
      "footer-socials": renderFooterSocials,
    };
    $$("[data-list]").forEach((container) => {
      const items = get(ctx, container.dataset.list);
      const fn = renderers[container.id];
      if (Array.isArray(items) && fn) {
        container.innerHTML = "";
        fn(container, items);
      }
    });
  }

  function renderNavLinks(container, links) {
    links.forEach((l) => {
      container.appendChild(el("li", {}, el("a", { href: l.href, text: l.label })));
    });
  }

  function renderPillars(container, pillars) {
    pillars.forEach((p, i) => {
      const points = el("ul", { class: "pillar__points" });
      (p.points || []).forEach((pt) => points.appendChild(el("li", { text: pt })));
      container.appendChild(
        el("article", { class: "pillar reveal", style: `--reveal-delay:${i * 110}ms` }, [
          el("div", { class: "pillar__top" }, [
            el("span", { class: "pillar__num", text: p.number }),
            el("span", { class: "pillar__icon" }, icon(p.icon)),
          ]),
          el("h3", { class: "pillar__title", text: p.title }),
          el("p", { class: "pillar__text", text: p.description }),
          points,
        ])
      );
    });
  }

  function renderAssurances(container, items) {
    items.forEach((a) => {
      container.appendChild(
        el("li", { class: "contact__value" }, [
          el("span", { class: "contact__value-title", text: a.title }),
          el("span", { class: "contact__value-text", text: a.text }),
        ])
      );
    });
  }

  function renderCategories(container, cats) {
    cats.forEach((c, i) => {
      const chips = el("div", { class: "category__chips" });
      if (c.styles && c.styles.length) {
        c.styles.forEach((st) => chips.appendChild(el("button", {
          class: "category__chip", type: "button", text: st,
          "data-filter-cat": c.filter, "data-filter-style": slug(st),
        })));
      } else {
        chips.appendChild(el("button", {
          class: "category__chip", type: "button", text: "Voir les réalisations",
          "data-filter-cat": c.filter,
        }));
      }
      container.appendChild(
        el("article", { class: "category reveal", style: `--reveal-delay:${i * 90}ms` }, [
          el("button", { class: "category__head", type: "button", "data-filter-cat": c.filter }, [
            el("span", { class: "category__icon" }, icon(c.icon)),
            el("span", { class: "category__title", text: c.name }),
            el("span", { class: "category__cue", "aria-hidden": "true", text: "Voir" }),
          ]),
          chips,
        ])
      );
    });
  }

  /* ---------- gallery grid: one tile per project ---------- */
  /* ---------- bento layout: assign span roles by VISIBLE order ----------------
     Repeating 6-card module (hero 2x2, cell, cell, tall 1x2, wide 2x1, wide 2x1)
     = a perfect 3-col x 4-row block, so the grid always ends on a flat baseline.
     The tail (count % 6) uses rectangle-perfect mini-layouts, and the whole grid
     re-packs whenever a filter hides/shows tiles.                              */
  const BENTO_MODULE = ["hero", "cell", "cell", "tall", "wide", "wide"];
  /* small / leftover counts: taller, balanced shapes (never a short full-width strip) */
  const BENTO_SMALL = {
    1: ["full2"],
    2: ["hero", "tall"],
    3: ["tall", "tall", "tall"],
    4: ["tall", "tall", "cell", "cell"],
    5: ["hero", "tall", "cell", "cell", "cell"],
  };
  const BENTO_ROLES = ["hero", "tall", "wide", "cell", "full", "full2"];
  function bentoRoles(n) {
    if (n <= 0) return [];
    if (n <= 5) return BENTO_SMALL[n].slice();
    const roles = [];
    const full = Math.floor(n / 6) * 6;
    for (let i = 0; i < full; i++) roles.push(BENTO_MODULE[i % 6]);
    const r = n - full;
    if (r) (BENTO_SMALL[r] || []).forEach((x) => roles.push(x));
    return roles;
  }
  function layoutBento(grid) {
    if (!grid) return;
    const all = Array.from(grid.children);
    all.forEach((t) => BENTO_ROLES.forEach((r) => t.classList.remove("showcase__item--" + r)));
    const visible = all.filter((t) => !t.classList.contains("is-hidden"));
    const roles = bentoRoles(visible.length);
    visible.forEach((t, i) => { if (roles[i]) t.classList.add("showcase__item--" + roles[i]); });
  }

  /* ---------- curate order: bright/modern first, heavy/traditional further down */
  const STYLE_RANK = { contemporain: 0, urbain: 1, classique: 2, champetre: 3 };
  const CAT_RANK = { cuisine: 0, "salle-de-bain": 1, autres: 2 };
  function curate(items) {
    return items
      .map((it, i) => ({ it, i }))
      .sort((a, b) => {
        const sa = STYLE_RANK[a.it.styleSlug] != null ? STYLE_RANK[a.it.styleSlug] : 5;
        const sb = STYLE_RANK[b.it.styleSlug] != null ? STYLE_RANK[b.it.styleSlug] : 5;
        if (sa !== sb) return sa - sb;
        const ca = CAT_RANK[a.it.category] != null ? CAT_RANK[a.it.category] : 9;
        const cb = CAT_RANK[b.it.category] != null ? CAT_RANK[b.it.category] : 9;
        if (ca !== cb) return ca - cb;
        return a.i - b.i;
      })
      .map((x) => x.it);
  }

  function renderGrid(container, items) {
    container.innerHTML = "";
    items.forEach((it, i) => {
      const tile = el("figure", {
        class: "showcase__item",
        tabindex: "0",
        role: "button",
        "data-index": String(i),
        "data-category": it.category || "",
        "data-style": it.styleSlug || "",
        "aria-label": (it.title ? it.title + " (agrandir)" : "Agrandir le projet"),
      });
      tile.appendChild(el("div", { class: "showcase__placeholder" }, icon("wood")));
      const media = el("img", { class: "showcase__media", src: (it.photos && it.photos[0]) || "", alt: it.title || "", loading: "lazy" });
      media.addEventListener("error", () => { media.style.display = "none"; });
      tile.appendChild(media);
      tile.appendChild(el("div", { class: "showcase__expand", "aria-hidden": "true" }));
      if (it.photos && it.photos.length > 1)
        tile.appendChild(el("span", { class: "showcase__count", "aria-hidden": "true", text: it.photos.length + " photos" }));
      tile.appendChild(el("figcaption", { class: "showcase__overlay" }, [
        it.styleLabel ? el("span", { class: "showcase__tag", text: it.styleLabel }) : null,
        el("span", { class: "showcase__title", text: it.title || "" }),
        it.caption ? el("span", { class: "showcase__caption", text: it.caption }) : null,
      ]));
      container.appendChild(tile);
    });
    layoutBento(container);
  }

  /* ---------- dynamic gallery from the /Photos folder --------------------------
     Photos/<Category>/<Style>/<Project>/*.jpg   (Cuisine, SalleDeBain)
     Photos/Autres/<Project>/*.jpg               (no style level)
     Read at runtime from the server's directory listing, so the client just
     adds / removes photos in the folder and the gallery follows. Works with any
     server that lists folders (VS Code Live Server, `python -m http.server`,
     and similar). Otherwise it falls back to the items in content.json.        */
  const PHOTOS_ROOT = "Photos/";
  const STYLE_LABEL = { classique: "Classique", contemporaine: "Contemporain", contemporain: "Contemporain", urbain: "Urbain", champetre: "Champêtre" };
  const isMedia = (n) => { n = n.toLowerCase(); return [".jpg", ".jpeg", ".png", ".webp", ".gif", ".avif", ".mp4", ".webm", ".mov"].some((e) => n.endsWith(e)); };
  const prettify = (s) => (s || "").replace(/_+/g, " ").replace(/([a-zà-ÿ])([A-ZÀ-Ÿ])/g, "$1 $2").replace(/ +/g, " ").trim();

  async function listDir(path) {
    try {
      const res = await fetch(path, { cache: "no-cache" });
      if (!res.ok) return [];
      const baseUrl = res.url || new URL(path, location.href).href;
      const origin = new URL(baseUrl).origin;
      const basePath = new URL(baseUrl).pathname.replace(/\/+$/, "");
      const doc = new DOMParser().parseFromString(await res.text(), "text/html");
      const out = [];
      const seen = new Set();
      doc.querySelectorAll("a[href]").forEach((aEl) => {
        let href = aEl.getAttribute("href");
        if (!href) return;
        href = href.split("#")[0].split("?")[0];
        if (!href || href.indexOf("://") !== -1) return;
        let abs;
        try { abs = new URL(href, baseUrl); } catch (e) { return; }
        if (abs.origin !== origin) return;
        const childPath = abs.pathname.replace(/\/+$/, "");
        if (!childPath || childPath === basePath) return;            // self
        if (basePath && childPath.indexOf(basePath + "/") !== 0) return; // not under this dir (breadcrumbs/parent)
        const rest = childPath.slice(basePath.length + 1);
        if (!rest || rest.indexOf("/") !== -1) return;              // only direct children
        const name = decodeURIComponent(rest);
        if (!name || name === "." || name === "..") return;
        if (seen.has(name)) return;
        seen.add(name);
        const cls = aEl.getAttribute("class") || "";
        const isDir = /\/$/.test(href) || /icon-directory/.test(cls); // python: trailing slash; serve-index: css class
        out.push({ name, isDir, url: abs.href });
      });
      return out;
    } catch (e) { return []; }
  }

  async function scanPhotos(ctx) {
    const cats = get(ctx, "categories.items") || [];
    const root = await listDir(PHOTOS_ROOT);
    if (!root.length) return [];
    const out = [];
    for (const cat of cats) {
      const dir = root.find((d) => d.isDir && slug(d.name) === slug(cat.folder || cat.name));
      if (!dir) continue;
      const lvl1 = (await listDir(dir.url)).filter((e) => e.isDir);
      const projects = [];
      if (cat.styles && cat.styles.length) {
        await Promise.all(lvl1.map(async (st) => {
          const label = STYLE_LABEL[slug(st.name)] || prettify(st.name);
          (await listDir(st.url)).filter((e) => e.isDir)
            .forEach((p) => projects.push({ url: p.url, name: p.name, styleLabel: label }));
        }));
      } else {
        lvl1.forEach((p) => projects.push({ url: p.url, name: p.name, styleLabel: "" }));
      }
      await Promise.all(projects.map(async (proj) => {
        const photos = (await listDir(proj.url)).filter((f) => !f.isDir && isMedia(f.name)).map((f) => f.url);
        if (photos.length) out.push({
          category: cat.filter,
          styleLabel: proj.styleLabel,
          styleSlug: proj.styleLabel ? slug(proj.styleLabel) : "",
          title: prettify(proj.name),
          caption: "",
          photos,
        });
      }));
    }
    return out;
  }

  function fallbackItems(ctx) {
    return (get(ctx, "realisations.items") || []).map((it) => ({
      category: it.category || "",
      styleLabel: it.style || "",
      styleSlug: it.style ? slug(it.style) : "",
      title: it.title || "",
      caption: it.caption || "",
      photos: [it.full || it.src].filter(Boolean),
    }));
  }

  async function buildGallery(ctx) {
    const grid = $("#showcase-grid");
    if (!grid) return [];
    let gallery = curate(fallbackItems(ctx));
    renderGrid(grid, gallery);
    // 1) live folder scan - works on servers that list directories (local dev),
    //    so the gallery auto-updates when photos are added/removed.
    try {
      const scanned = await scanPhotos(ctx);
      if (scanned.length) { gallery = curate(scanned); renderGrid(grid, gallery); return gallery; }
    } catch (e) { /* no directory listing -> fall through to the manifest */ }
    // 2) prebuilt manifest - works on any static host (Vercel, GitHub Pages...).
    try {
      const res = await fetch("photos.json", { cache: "no-cache" });
      if (res.ok) {
        const data = await res.json();
        if (Array.isArray(data) && data.length) { gallery = curate(data); renderGrid(grid, gallery); }
      }
    } catch (e) { /* keep the content.json fallback */ }
    return gallery;
  }

  function renderTestimonials(container, items) {
    items.forEach((t, i) => {
      container.appendChild(
        el("figure", { class: "quote reveal", style: `--reveal-delay:${i * 80}ms` }, [
          el("div", { class: "quote__mark", "aria-hidden": "true", text: "“" }),
          el("blockquote", { class: "quote__text", text: t.quote }),
          el("figcaption", {}, [
            el("div", { class: "quote__author", text: t.author }),
            t.location ? el("div", { class: "quote__loc", text: t.location }) : null,
          ]),
        ])
      );
    });
  }

  function renderContactDetails(container, details) {
    details.forEach((d) => {
      const valueNode = d.href
        ? el("a", { class: "contact__place-value", href: d.href, text: d.value })
        : el("span", { class: "contact__place-value", text: d.value });
      const li = el("li", { class: "contact__place" }, [
        el("span", { class: "contact__place-label", text: d.label }),
        valueNode,
      ]);
      if (d.sub) li.appendChild(el("span", { class: "contact__place-sub", text: d.sub }));
      container.appendChild(li);
    });
  }

  function renderFooterCols(container, cols) {
    cols.forEach((col) => {
      const ul = el("ul");
      (col.links || []).forEach((l) =>
        ul.appendChild(el("li", {}, el("a", { href: l.href, text: l.label })))
      );
      container.appendChild(
        el("div", { class: "footer__col" }, [
          el("h3", { class: "footer__col-title", text: col.title }),
          ul,
        ])
      );
    });
  }

  function renderFooterSocials(container, socials) {
    socials.forEach((s) => {
      const link = el(
        "a",
        {
          class: "footer__social",
          href: s.href,
          target: "_blank",
          rel: "noopener noreferrer",
          "aria-label": s.label,
          title: s.label,
          "data-brand": s.brand || slug(s.label),
        },
        icon(s.icon)
      );
      container.appendChild(el("li", {}, link));
    });
  }

  /* ---------- header elevate on scroll ---------- */
  function initHeader() {
    const header = $("#site-header");
    if (!header) return;
    const onScroll = () => {
      header.toggleAttribute("data-elevated", window.scrollY > 24);
    };
    onScroll();
    window.addEventListener("scroll", onScroll, { passive: true });
  }

  /* ---------- mobile nav ---------- */
  function initMobileNav() {
    const toggle = $("#nav-toggle");
    const panel = $("#mobile-nav");
    if (!toggle || !panel) return;

    const setOpen = (open) => {
      toggle.setAttribute("aria-expanded", String(open));
      panel.hidden = !open;
      toggle.setAttribute("aria-label", open ? "Fermer le menu" : "Ouvrir le menu");
    };
    toggle.addEventListener("click", () =>
      setOpen(toggle.getAttribute("aria-expanded") !== "true")
    );
    panel.addEventListener("click", (e) => {
      if (e.target.closest("a")) setOpen(false);
    });
  }

  /* ---------- reveal on scroll ---------- */
  function initReveal() {
    const els = $$(".reveal");
    if (!("IntersectionObserver" in window) || prefersReduced()) {
      els.forEach((n) => n.classList.add("is-visible"));
      return;
    }
    const io = new IntersectionObserver(
      (entries, obs) => {
        entries.forEach((e) => {
          if (e.isIntersecting) {
            e.target.classList.add("is-visible");
            obs.unobserve(e.target);
          }
        });
      },
      { threshold: 0.12, rootMargin: "0px 0px -8% 0px" }
    );
    els.forEach((n) => io.observe(n));
  }

  /* contact: no form - visitors call or email directly */

  /* ---------- footer year ---------- */
  function setFooterYear() {
    $$("[data-year]").forEach((n) => (n.textContent = new Date().getFullYear()));
  }

  /* ===================================================================
     PORTFOLIO LIGHTBOX - click a project to open a full-screen viewer;
     cycle through every photo/clip with arrows, keyboard, or backdrop.
     =================================================================== */
  function initLightbox(gallery) {
    const grid = $("#showcase-grid");
    const box = $("#lightbox");
    if (!grid || !box || !Array.isArray(gallery) || !gallery.length) return;

    const stage = $("#lightbox-stage");
    const caption = $("#lightbox-caption");
    const counter = $("#lightbox-counter");
    const closeBtn = $("#lightbox-close");
    const prevBtn = $("#lightbox-prev");
    const nextBtn = $("#lightbox-next");
    let current = null, photos = [], pos = 0, lastFocus = null;

    const stopMedia = () => { const v = stage.querySelector("video"); if (v) { try { v.pause(); } catch (e) {} } };
    const isVid = (u) => { u = u.toLowerCase(); return u.endsWith(".mp4") || u.endsWith(".webm") || u.endsWith(".mov"); };

    const render = () => {
      stopMedia();
      stage.innerHTML = "";
      const url = photos[pos] || "";
      let node;
      if (isVid(url)) {
        node = el("video", { class: "lightbox__media", src: url, controls: "", playsinline: "", preload: "metadata" });
        const pl = node.play && node.play(); if (pl && pl.catch) pl.catch(() => {});
      } else {
        node = el("img", { class: "lightbox__media", src: url, alt: current ? current.title : "" });
        node.addEventListener("error", () => node.replaceWith(el("div", { class: "lightbox__placeholder" }, icon("wood"))));
      }
      stage.appendChild(node);
      caption.innerHTML = "";
      if (current && current.styleLabel) caption.appendChild(el("span", { class: "lightbox__tag", text: current.styleLabel }));
      if (current) caption.appendChild(el("span", { class: "lightbox__title", text: current.title || "" }));
      counter.textContent = photos.length > 1 ? `${pos + 1} / ${photos.length}` : "";
    };

    const open = (tile) => {
      current = gallery[Number(tile.dataset.index)];
      if (!current) return;
      photos = current.photos || []; pos = 0;
      lastFocus = document.activeElement;
      box.hidden = false; box.setAttribute("aria-hidden", "false");
      document.body.style.overflow = "hidden";
      render();
      requestAnimationFrame(() => box.classList.add("is-open"));
      closeBtn.focus();
    };
    const close = () => {
      stopMedia();
      box.classList.remove("is-open"); box.setAttribute("aria-hidden", "true");
      document.body.style.overflow = "";
      setTimeout(() => { box.hidden = true; stage.innerHTML = ""; }, 300);
      if (lastFocus && lastFocus.focus) lastFocus.focus();
    };
    const go = (d) => { if (photos.length < 2) return; pos = (pos + d + photos.length) % photos.length; render(); };

    grid.addEventListener("click", (e) => { const t = e.target.closest("[data-index]"); if (t && !t.classList.contains("is-hidden")) open(t); });
    grid.addEventListener("keydown", (e) => { if (e.key !== "Enter" && e.key !== " ") return; const t = e.target.closest("[data-index]"); if (t) { e.preventDefault(); open(t); } });
    closeBtn.addEventListener("click", close);
    prevBtn.addEventListener("click", () => go(-1));
    nextBtn.addEventListener("click", () => go(1));
    box.addEventListener("click", (e) => { if (e.target === box) close(); });
    document.addEventListener("keydown", (e) => { if (box.hidden) return; if (e.key === "Escape") close(); else if (e.key === "ArrowLeft") go(-1); else if (e.key === "ArrowRight") go(1); });
  }

  /* ---------- showcase filters: category cards + gallery filter bar ---------- */
  function initShowcaseFilter(ctx) {
    const grid = $("#showcase-grid");
    if (!grid) return;
    const catBar = $("#filter-cats");
    const styleBar = $("#filter-styles");
    const empty = $("#showcase-empty");
    const cats = get(ctx, "categories.items") || [];

    // unique, ordered style list drawn from the categories' own styles
    const FILTER_ORDER = { contemporain: 0, classique: 1, urbain: 2, champetre: 3 };
    const styleMap = new Map();
    cats.forEach((c) => (c.styles || []).forEach((st) => {
      const sl = slug(st);
      if (sl && !styleMap.has(sl)) styleMap.set(sl, st);
    }));
    const styleList = Array.from(styleMap, (entry) => ({ sl: entry[0], label: entry[1] }))
      .sort((a, b) => (FILTER_ORDER[a.sl] != null ? FILTER_ORDER[a.sl] : 9) - (FILTER_ORDER[b.sl] != null ? FILTER_ORDER[b.sl] : 9));

    const mkTag = (label, value, kind) => {
      const attrs = { class: "filter-tag", type: "button", text: label };
      attrs["data-" + kind] = value;
      return el("button", attrs);
    };

    if (catBar) {
      catBar.innerHTML = "";
      catBar.appendChild(mkTag("Tout", "all", "cat"));
      cats.forEach((c) => catBar.appendChild(mkTag(c.name, c.filter, "cat")));
    }
    if (styleBar) {
      styleBar.innerHTML = "";
      styleBar.appendChild(mkTag("Tous les styles", "all", "style"));
      styleList.forEach((s) => styleBar.appendChild(mkTag(s.label, s.sl, "style")));
    }

    let activeCat = "all";
    let activeStyle = "all";

    const markActive = () => {
      if (catBar) $$(".filter-tag", catBar).forEach((b) => b.classList.toggle("is-active", (b.dataset.cat || "all") === activeCat));
      if (styleBar) $$(".filter-tag", styleBar).forEach((b) => b.classList.toggle("is-active", (b.dataset.style || "all") === activeStyle));
    };

    const apply = () => {
      // categories without styles (e.g. Sur-mesure) ignore + disable the style row
      const catCfg = cats.find((c) => c.filter === activeCat);
      const catHasStyles = activeCat === "all" || !catCfg || !!(catCfg.styles && catCfg.styles.length);
      if (!catHasStyles) activeStyle = "all";
      if (styleBar) styleBar.classList.toggle("is-disabled", !catHasStyles);
      let shown = 0;
      $$("[data-index]", grid).forEach((t) => {
        const okCat = activeCat === "all" || t.dataset.category === activeCat;
        const okStyle = activeStyle === "all" || t.dataset.style === activeStyle;
        const ok = okCat && okStyle;
        t.classList.toggle("is-hidden", !ok);
        if (ok) shown += 1;
      });
      layoutBento(grid);
      if (empty) empty.hidden = shown !== 0;
      markActive();
    };

    const change = () => {
      grid.classList.add("is-rearranging");
      window.setTimeout(() => {
        apply();
        grid.classList.remove("is-rearranging");
      }, 200);
    };

    if (catBar) catBar.addEventListener("click", (e) => {
      const b = e.target.closest(".filter-tag");
      if (!b) return;
      activeCat = b.dataset.cat || "all";
      change();
    });
    if (styleBar) styleBar.addEventListener("click", (e) => {
      const b = e.target.closest(".filter-tag");
      if (!b) return;
      activeStyle = b.dataset.style || "all";
      change();
    });

    apply();
  }

  /* ===================================================================
     HERO - chooses the WebGL scene or a media fallback
     =================================================================== */
  function webglAvailable() {
    try {
      const c = document.createElement("canvas");
      return !!(window.WebGLRenderingContext &&
        (c.getContext("webgl") || c.getContext("experimental-webgl")));
    } catch { return false; }
  }

  // Three.js is fetched lazily (never on the critical path). It is only
  // requested on capable desktops, so phones / reduced-motion never pay the
  // ~600 KB cost - and content paints before the engine is even requested.
  const THREE_URL = "https://cdnjs.cloudflare.com/ajax/libs/three.js/r128/three.min.js";
  let threePromise = null;
  function loadThree() {
    if (window.THREE) return Promise.resolve();
    if (threePromise) return threePromise;
    threePromise = new Promise((resolve, reject) => {
      const s = document.createElement("script");
      s.src = THREE_URL;
      s.async = true;
      s.onload = () => resolve();
      s.onerror = () => reject(new Error("three.js failed to load"));
      document.head.appendChild(s);
    });
    return threePromise;
  }

  function initHero(ctx) {
    const hero = $("#hero");
    const canvas = $("#hero-canvas");
    if (!hero || !canvas) return;
    const media = get(ctx, "hero.media") || {};
    const reduce = prefersReduced();

    // Skip the 3D engine entirely on phones, reduced-motion, or no WebGL.
    if (matchMedia("(max-width: 760px)").matches || reduce || !webglAvailable()) {
      buildHeroFallback(hero, canvas, media, reduce);
      return;
    }
    // Capable desktop: load Three.js after paint, then build the scene.
    loadThree()
      .then(() => { initHero3D(canvas, hero); hero.classList.add("hero--webgl"); })
      .catch((err) => {
        console.warn("[hero] 3D unavailable - using media fallback:", err);
        buildHeroFallback(hero, canvas, media, false);
      });
  }

  /* ---------- video/image fallback layer ---------- */
  function buildHeroFallback(hero, canvas, media, reduce) {
    hero.classList.add("hero--fallback");
    if (canvas) canvas.style.display = "none";

    const layer = el("div", { class: "hero__media", "aria-hidden": "true" });
    let node;

    if (media.video && !reduce) {
      node = el("video", {
        autoplay: "", loop: "", playsinline: "", preload: "auto",
        poster: media.poster || "",
      });
      node.muted = true;            // required for autoplay
      node.appendChild(el("source", { src: media.video, type: "video/mp4" }));
    } else {
      node = el("img", { src: media.image || media.poster || "", alt: media.alt || "" });
    }

    node.addEventListener("error", () => layer.classList.add("is-empty"));
    const ready = () => layer.classList.add("is-ready");
    node.addEventListener("loadeddata", ready);
    node.addEventListener("load", ready);

    layer.appendChild(node);
    hero.insertBefore(layer, hero.firstChild);

    if (node.tagName === "VIDEO") {
      const p = node.play && node.play();
      if (p && p.catch) p.catch(() => {/* autoplay blocked -> poster stays */});
    }
  }

  /* ---------- soft "studio" environment for refined reflections ---------- */
  function makeStudioEnv(renderer) {
    const THREE = window.THREE;
    const c = document.createElement("canvas");
    c.width = 16; c.height = 128;
    const g = c.getContext("2d");
    const grad = g.createLinearGradient(0, 0, 0, 128);
    grad.addColorStop(0.0, "#fbf4e7");   // warm sky
    grad.addColorStop(0.5, "#cdbfa8");
    grad.addColorStop(1.0, "#3b2f22");   // warm ground
    g.fillStyle = grad; g.fillRect(0, 0, 16, 128);

    const tex = new THREE.CanvasTexture(c);
    tex.mapping = THREE.EquirectangularReflectionMapping;
    if ("sRGBEncoding" in THREE) tex.encoding = THREE.sRGBEncoding;

    const pmrem = new THREE.PMREMGenerator(renderer);
    const rt = pmrem.fromEquirectangular(tex);
    tex.dispose(); pmrem.dispose();
    return rt.texture;
  }

  /* ===================================================================
     HERO 3D - luxury kitchen showroom (architectural corner)
       - left: appliance tower (flush ovens) + pantry/wine tower
       - center: base run + stone counter + backsplash + upper cabinets
                 with open oak accent shelves breaking the matte blocks
       - right: tall open oak shelving tower
       - island: drawers + brass J-pulls, inset sink + gooseneck faucet,
                 waterfall top with overhang seating + two stools
       - warm window sun + fog blend; scroll dollies island -> wall and
         glides the island drawers open. Grouped primitives, shared mats.
     =================================================================== */
  function initHero3D(canvas, hero) {
    const THREE = window.THREE;

    const renderer = new THREE.WebGLRenderer({ canvas, antialias: true, alpha: true, powerPreference: "high-performance" });
    renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 2));
    renderer.setClearColor(0x000000, 0);
    if ("outputEncoding" in renderer) renderer.outputEncoding = THREE.sRGBEncoding;
    renderer.toneMapping = THREE.ACESFilmicToneMapping;
    renderer.toneMappingExposure = 0.7;
    renderer.shadowMap.enabled = true;
    renderer.shadowMap.type = THREE.PCFSoftShadowMap;

    const BG = 0xf6f2ea;
    const scene = new THREE.Scene();
    scene.fog = new THREE.Fog(BG, 8.5, 20);
    const camera = new THREE.PerspectiveCamera(38, 1, 0.1, 100);

    try { scene.environment = makeStudioEnv(renderer); } catch (e) { /* optional */ }

    /* procedural white-oak grain */
    function makeWoodTexture() {
      const cv = document.createElement("canvas"); cv.width = 256; cv.height = 512;
      const g = cv.getContext("2d");
      g.fillStyle = "#c9ac80"; g.fillRect(0, 0, 256, 512);
      for (let i = 0; i < 90; i++) {
        const gx = Math.random() * 256;
        g.strokeStyle = `rgba(${(108 + Math.random() * 46) | 0},${(84 + Math.random() * 32) | 0},${(54 + Math.random() * 26) | 0},${(0.04 + Math.random() * 0.1).toFixed(3)})`;
        g.lineWidth = 0.5 + Math.random() * 1.6;
        g.beginPath(); g.moveTo(gx, 0);
        for (let y = 0; y <= 512; y += 22) g.lineTo(gx + (Math.random() - 0.5) * 7, y);
        g.stroke();
      }
      const t = new THREE.CanvasTexture(cv);
      t.wrapS = t.wrapT = THREE.RepeatWrapping;
      if ("sRGBEncoding" in THREE) t.encoding = THREE.sRGBEncoding;
      t.anisotropy = 4; return t;
    }

    /* large-format stone-tile floor (procedural, one texture) */
    function makeFloorTexture() {
      const cv = document.createElement("canvas"); cv.width = 1024; cv.height = 1024;
      const x = cv.getContext("2d");
      x.fillStyle = "#3a3936"; x.fillRect(0, 0, 1024, 1024);
      const tiles = 4, ts = 1024 / tiles;
      for (let iy = 0; iy < tiles; iy++) for (let ix = 0; ix < tiles; ix++) {
        const tone = (44 + Math.random() * 13) | 0;
        x.fillStyle = `rgb(${tone + 5},${tone + 3},${tone})`;
        x.fillRect(ix * ts + 3, iy * ts + 3, ts - 6, ts - 6);
        x.strokeStyle = "rgba(255,250,240,0.04)"; x.lineWidth = 1.2;
        for (let v = 0; v < 4; v++) {
          let px = ix * ts + Math.random() * ts, py = iy * ts + 6; x.beginPath(); x.moveTo(px, py);
          for (let st = 0; st < 6; st++) { px += (Math.random() - 0.5) * ts * 0.35; py += (ts - 12) / 6; x.lineTo(px, py); }
          x.stroke();
        }
      }
      x.strokeStyle = "rgba(0,0,0,0.5)"; x.lineWidth = 4;
      for (let i = 0; i <= tiles; i++) { x.beginPath(); x.moveTo(i * ts, 0); x.lineTo(i * ts, 1024); x.stroke(); x.beginPath(); x.moveTo(0, i * ts); x.lineTo(1024, i * ts); x.stroke(); }
      const t = new THREE.CanvasTexture(cv);
      t.wrapS = t.wrapT = THREE.RepeatWrapping; t.repeat.set(8, 8);
      if ("sRGBEncoding" in THREE) t.encoding = THREE.sRGBEncoding;
      t.anisotropy = 4; return t;
    }

    /* materials (shared) */
    const oak = new THREE.MeshStandardMaterial({ map: makeWoodTexture(), color: 0xbf9f6e, roughness: 0.7, metalness: 0.0, envMapIntensity: 0.35 });
    const charcoal = new THREE.MeshStandardMaterial({ color: 0x1f1f1f, roughness: 0.7, metalness: 0.0, envMapIntensity: 0.35 });
    const carcass = new THREE.MeshStandardMaterial({ color: 0x121212, roughness: 0.95, metalness: 0.0, envMapIntensity: 0.3 });
    const stone = new THREE.MeshStandardMaterial({ color: 0xd0c7b2, roughness: 0.3, metalness: 0.08, envMapIntensity: 0.6 });
    const brass = new THREE.MeshStandardMaterial({ color: 0xc5a880, roughness: 0.26, metalness: 0.92, envMapIntensity: 1.0 });
    const glass = new THREE.MeshStandardMaterial({ color: 0x0d0e12, roughness: 0.16, metalness: 0.55, envMapIntensity: 1.0 });
    const steel = new THREE.MeshStandardMaterial({ color: 0x8d9296, roughness: 0.4, metalness: 0.85, envMapIntensity: 1.0 });
    const floorMat = new THREE.MeshStandardMaterial({ map: makeFloorTexture(), color: 0xffffff, roughness: 0.55, metalness: 0.05, envMapIntensity: 0.4 });
    const wallMat = new THREE.MeshStandardMaterial({ color: 0xbeb29a, roughness: 1.0, metalness: 0.0, envMapIntensity: 0.2 });
    const fadeMats = [oak, charcoal, stone, brass, glass, steel];

    const box = (w, h, d, mat) => { const m = new THREE.Mesh(new THREE.BoxGeometry(w, h, d), mat); m.castShadow = true; m.receiveShadow = true; return m; };
    const cyl = (rt, rb, h, mat, seg) => { const m = new THREE.Mesh(new THREE.CylinderGeometry(rt, rb, h, seg || 20), mat); m.castShadow = true; m.receiveShadow = true; return m; };

    /* lighting: low ambient + strong raking window sun = deep, chiselled contrast */
    scene.add(new THREE.AmbientLight(0xffe7c8, 0.20));
    scene.add(new THREE.HemisphereLight(0xfff6ec, 0xbfae95, 0.18));
    const sun = new THREE.DirectionalLight(0xfff0d2, 1.5);
    sun.position.set(-10, 6, 5);              // raking from the left to carve the door gaps
    sun.castShadow = true;
    sun.shadow.mapSize.set(2048, 2048);
    sun.shadow.radius = 6;
    sun.shadow.bias = -0.0003;
    sun.shadow.normalBias = 0.045;
    Object.assign(sun.shadow.camera, { near: 1, far: 30, left: -13, right: 10, top: 11, bottom: -8 });
    sun.shadow.camera.updateProjectionMatrix();
    scene.add(sun);
    const fill = new THREE.DirectionalLight(0xcfe0ff, 0.38); fill.position.set(8, 4.5, 5); scene.add(fill);
    const fridgeFill = new THREE.PointLight(0xffe6c4, 0.32, 11, 2); fridgeFill.position.set(4.0, 2.3, 1.2); scene.add(fridgeFill); // reveals the far-right fridge
    const bounce = new THREE.PointLight(0xffc188, 0.2, 16, 2); bounce.position.set(2.4, 1.1, 3.6); scene.add(bounce);
    const wineGlow = new THREE.PointLight(0xffcf9a, 0.5, 2.6, 2); wineGlow.position.set(-3.25, 0.6, -2.9); scene.add(wineGlow);

    /* shell: floor + corner walls */
    const floor = new THREE.Mesh(new THREE.PlaneGeometry(60, 60), floorMat);
    floor.rotation.x = -Math.PI / 2; floor.receiveShadow = true; scene.add(floor);
    const backWall = new THREE.Mesh(new THREE.PlaneGeometry(40, 9), wallMat);
    backWall.position.set(-1, 4.5, -3.42); backWall.receiveShadow = true; scene.add(backWall);
    const leftWall = new THREE.Mesh(new THREE.PlaneGeometry(24, 9), wallMat);
    leftWall.rotation.y = Math.PI / 2; leftWall.position.set(-6.4, 4.5, 3); leftWall.receiveShadow = false; scene.add(leftWall);
    // ceiling defines the top architectural line
    const ceilMat = new THREE.MeshStandardMaterial({ color: 0x191919, roughness: 1.0, side: THREE.DoubleSide });
    const ceiling = new THREE.Mesh(new THREE.PlaneGeometry(44, 34), ceilMat);
    ceiling.rotation.x = Math.PI / 2; ceiling.position.set(-1, 2.98, 0); ceiling.castShadow = false; scene.add(ceiling);
    // back soffit / bulkhead over the cabinetry + warm linear ceiling coves
    // (soffit removed: it intersected the full-height cabinet tops, causing z-fighting at the top of the armoires)
    // invisible warm downlights pooling over the island + counter (no visible fixtures)
    const counterLight = new THREE.PointLight(0xffe6c4, 0.45, 8, 2); counterLight.position.set(-0.9, 2.6, -2.2); scene.add(counterLight);
    // large minimalist window on the LEFT wall (mullions cast pane shadows)
    const win = new THREE.Group(); win.position.set(-6.32, 1.55, 1.2); scene.add(win);
    const WW = 3.4, WH = 2.5;
    const winBar = (w, h, d, y, z) => { const b = box(w, h, d, steel); b.position.set(0, y, z); win.add(b); };
    winBar(0.1, 0.08, WW, WH / 2, 0); winBar(0.1, 0.08, WW, -WH / 2, 0);
    winBar(0.1, WH, 0.08, 0, WW / 2); winBar(0.1, WH, 0.08, 0, -WW / 2);
    winBar(0.07, WH, 0.06, 0, -WW / 6); winBar(0.07, WH, 0.06, 0, WW / 6);
    winBar(0.07, 0.06, WW, -WH / 6, 0); winBar(0.07, 0.06, WW, WH / 6, 0);

    /* intro registry + local helpers */
    const intro = [];
    const reg = (obj, from, stagger) => { intro.push({ obj, home: obj.position.clone(), from, stagger: stagger || 0 }); return obj; };
    const V = (x, y, z) => new THREE.Vector3(x, y, z);
    const WALLZ = -2.74, GAP = 0.025, CEIL = 2.9;
    const pullH = (g, x, y, len) => { const p = box(len, 0.02, 0.03, brass); p.position.set(x, y, WALLZ + 0.05); g.add(p); };
    const pullV = (g, x, y, len) => { const p = box(0.022, len, 0.03, brass); p.position.set(x, y, WALLZ + 0.05); g.add(p); };
    const bodyBox = (g, x, y, w, h, d) => { const b = box(w, h, d, charcoal); b.position.set(x, y, WALLZ - d / 2); g.add(b); return b; };
    const front = (g, x, y, w, h, mat) => { const f = box(w - GAP, h - GAP, 0.04, mat); f.position.set(x, y, WALLZ + 0.02); g.add(f); return f; };

    /* ---------- LEFT: appliance + pantry/wine towers ---------- */
    const towersG = new THREE.Group(); scene.add(towersG);
    // appliance tower
    bodyBox(towersG, -4.2, CEIL / 2, 0.92, CEIL, 0.62);
    front(towersG, -4.2, 0.32, 0.88, 0.52, charcoal); pullH(towersG, -4.2, 0.52, 0.5);
    [0.95, 1.43].forEach((oy) => {
      const trim = box(0.9, 0.46, 0.05, steel); trim.position.set(-4.2, oy, WALLZ + 0.015); towersG.add(trim);
      const gpan = box(0.78, 0.36, 0.04, glass); gpan.position.set(-4.2, oy, WALLZ + 0.05); towersG.add(gpan);
      const bar = box(0.62, 0.035, 0.05, steel); bar.position.set(-4.2, oy + 0.2, WALLZ + 0.075); towersG.add(bar);
    });
    front(towersG, -4.2, 1.78, 0.88, 0.26, glass); pullH(towersG, -4.2, 1.88, 0.5);
    front(towersG, -4.2, 2.47, 0.88, 0.82, charcoal); pullV(towersG, -4.61, 2.47, 0.6);
    // pantry / wine tower
    bodyBox(towersG, -3.25, CEIL / 2, 0.94, CEIL, 0.62);
    const wineGlass = box(0.86, 1.04, 0.04, glass); wineGlass.position.set(-3.25, 0.6, WALLZ + 0.05); towersG.add(wineGlass);
    for (let r = 0; r < 4; r++) { const rack = box(0.74, 0.02, 0.34, steel); rack.position.set(-3.25, 0.28 + r * 0.24, WALLZ - 0.12); towersG.add(rack); }
    pullV(towersG, -3.66, 0.6, 0.7);
    front(towersG, -3.47, 1.85, 0.46, 1.74, charcoal); pullV(towersG, -3.27, 1.85, 0.7);
    front(towersG, -3.03, 1.85, 0.46, 1.74, charcoal); pullV(towersG, -3.23, 1.85, 0.7);
    reg(towersG, V(0, 0, 0.16), 0.05);

    /* ---------- CENTER: base run + counter + uppers ---------- */
    const counterG = new THREE.Group(); scene.add(counterG);
    bodyBox(counterG, -0.85, 0.45, 3.7, 0.9, 0.6);
    { const bx0 = -2.7, bx1 = 1.0, bn = 4, bw = (bx1 - bx0) / bn;
      for (let i = 0; i < bn; i++) { const cx = bx0 + bw * i + bw / 2; front(counterG, cx, 0.45, bw, 0.86, charcoal); pullH(counterG, cx, 0.8, bw - 0.22); } }
    const ctop = box(3.9, 0.06, 0.66, stone); ctop.position.set(-0.85, 0.95, WALLZ + 0.02); counterG.add(ctop);
    const bsplash = box(3.7, 0.62, 0.03, stone); bsplash.position.set(-0.85, 1.3, WALLZ - 0.28); counterG.add(bsplash);
    reg(counterG, V(0, -0.4, 0), 0.12);

    const uppersG = new THREE.Group(); scene.add(uppersG);
    bodyBox(uppersG, -1.85, 2.12, 1.75, 1.0, 0.42);
    bodyBox(uppersG, 0.55, 2.12, 0.95, 1.0, 0.42);
    [-2.4, -1.85, -1.3].forEach((cx) => { front(uppersG, cx, 2.12, 0.55, 0.98, charcoal); pullH(uppersG, cx, 1.69, 0.36); });
    front(uppersG, 0.55, 2.12, 0.9, 0.98, charcoal); pullH(uppersG, 0.55, 1.69, 0.55);
    reg(uppersG, V(0, 0.3, 0), 0.2);

    // open oak accent shelves (center gap), proud of the matte blocks
    const shelvesG = new THREE.Group(); scene.add(shelvesG);
    const shBack = box(1.15, 1.0, 0.03, oak); shBack.position.set(-0.45, 2.12, WALLZ - 0.18); shelvesG.add(shBack);
    [1.72, 2.12, 2.52].forEach((sy) => { const sh = box(1.15, 0.05, 0.34, oak); sh.position.set(-0.45, sy, WALLZ + 0.0); shelvesG.add(sh); });
    const v1 = cyl(0.05, 0.07, 0.26, charcoal, 18); v1.position.set(-0.78, 1.87, WALLZ + 0.0); shelvesG.add(v1);
    const b1 = new THREE.Mesh(new THREE.SphereGeometry(0.09, 18, 12), stone); b1.scale.y = 0.6; b1.position.set(-0.18, 2.59, WALLZ + 0.0); shelvesG.add(b1);
    const bk = box(0.26, 0.18, 0.2, brass); bk.position.set(-0.5, 2.24, WALLZ + 0.0); shelvesG.add(bk);
    reg(shelvesG, V(0, 0.4, 0), 0.3);

    /* ---------- RIGHT: ONE continuous custom-millwork run ----------
       counter-run end -> open oak shelving -> integrated fridge tower.
       Shared carcass (back + toe-kick) + 3 full-height gables + a continuous
       top band of caissons superieurs => flush facades, zero dark voids.      */
    const rightRunG = new THREE.Group(); scene.add(rightRunG);
    const RD = 0.6;                                         // run depth
    // continuous shell: full-height back panel + toe-kick (eliminates all gaps)
    const runBack = box(2.95, CEIL, 0.05, charcoal); runBack.position.set(2.475, CEIL / 2, WALLZ - RD + 0.03); rightRunG.add(runBack);
    const runBase = box(2.95, 0.12, RD, carcass);    runBase.position.set(2.475, 0.06, WALLZ - RD / 2); rightRunG.add(runBase);
    // full-height gables (joues de finition): left end | shelving|fridge | right end
    [1.03, 2.08, 3.92].forEach((gx) => { const g = box(0.06, 2.40, RD, charcoal); g.position.set(gx, 1.32, WALLZ - RD / 2); rightRunG.add(g); });
    // continuous top band of closed upper cabinets -> single unbroken ceiling line
    front(rightRunG, 1.525, 2.70, 1.05, 0.36, charcoal);   // top box over shelving
    front(rightRunG, 3.0,   2.70, 1.90, 0.36, charcoal);   // caisson superieur over the fridge

    // (A) open oak shelving bay (1.03..2.08) - flush to counter run (L) and fridge gable (R)
    front(rightRunG, 1.525, 0.56, 1.02, 0.86, charcoal); pullH(rightRunG, 1.525, 0.92, 0.55); // lower cabinet
    // full oak back panel that fills the whole bay (no dark show-through behind)
    const sBack = box(1.06, 1.6, 0.03, oak); sBack.position.set(1.525, 1.76, WALLZ - 0.18); rightRunG.add(sBack);
    // oak top + bottom caps close the bay (nothing visible through the top or bottom)
    [1.0, 2.52].forEach((sy) => { const cap = box(1.0, 0.06, 0.36, oak); cap.position.set(1.525, sy, WALLZ - 0.03); rightRunG.add(cap); });
    // the three display shelves
    [1.26, 1.78, 2.3].forEach((sy) => { const sh = box(0.95, 0.05, 0.34, oak); sh.position.set(1.525, sy, WALLZ - 0.02); rightRunG.add(sh); });
    const rv = cyl(0.05, 0.07, 0.24, charcoal, 18); rv.position.set(1.32, 1.38, WALLZ - 0.04); rightRunG.add(rv);
    const rbo = new THREE.Mesh(new THREE.SphereGeometry(0.085, 18, 12), stone); rbo.scale.y = 0.6; rbo.position.set(1.72, 2.4, WALLZ - 0.04); rightRunG.add(rbo);
    const rk = box(0.2, 0.16, 0.18, brass); rk.position.set(1.6, 1.9, WALLZ - 0.04); rightRunG.add(rk);

    // (B) integrated fridge enclosure (2.08..3.92) - doors flush inside the cavity
    front(rightRunG, 3.0, 0.55, 1.74, 0.82, charcoal); pullH(rightRunG, 3.0, 0.88, 1.2);      // freezer drawer
    front(rightRunG, 3.0 - 0.445, 1.74, 0.86, 1.46, charcoal);                                // French door - left
    front(rightRunG, 3.0 + 0.445, 1.74, 0.86, 1.46, charcoal);                                // French door - right
    pullV(rightRunG, 3.0 - 0.06, 1.74, 1.2); pullV(rightRunG, 3.0 + 0.06, 1.74, 1.2);         // vertical brass handles

    reg(rightRunG, V(0, 0, 0.16), 0.28);

    /* ---------- ISLAND ---------- */
    const island = new THREE.Group(); island.position.set(1.05, 0, 0.45); scene.add(island);
    const IW = 2.8, ID = 1.2, IH = 0.82, topY = 0.12 + IH + 0.04;
    const plinth = box(IW - 0.24, 0.12, ID - 0.2, carcass); plinth.position.set(0, 0.06, 0); island.add(plinth);
    const ibody = box(IW, IH, ID, charcoal); ibody.position.set(0, 0.12 + IH / 2, 0); island.add(ibody);
    const itop = box(IW + 0.06, 0.08, ID + 0.5, stone); itop.position.set(0, topY, 0.2); island.add(itop);
    const wfA = box(0.08, topY + 0.04, ID + 0.5, stone); wfA.position.set(-IW / 2, (topY + 0.04) / 2, 0.2); island.add(wfA);
    const wfB = box(0.08, topY + 0.04, ID + 0.5, stone); wfB.position.set(IW / 2, (topY + 0.04) / 2, 0.2); island.add(wfB);
    // sink basin - one dark inset sitting ~6 mm proud of the stone so no face
    // is coplanar with the countertop (prevents Z-fighting flicker)
    const sinkBasin = box(0.56, 0.07, 0.4, carcass); sinkBasin.position.set(-0.55, topY + 0.011, -0.28); island.add(sinkBasin);
    const drain = cyl(0.028, 0.028, 0.012, steel, 16); drain.position.set(-0.55, topY + 0.05, -0.28); island.add(drain);
    // ---- faucet assembly: ONE group holds base + gooseneck + spout + lever ----
    // (every part is a child in relative coords, so rotating/moving the group
    //  keeps the lever perfectly glued to the stem at any angle)
    const faucetGroup = new THREE.Group();
    faucetGroup.position.set(-0.55, topY + 0.04, -0.05);  // base sits in front of the basin
    const fBase = cyl(0.05, 0.06, 0.05, brass, 18); fBase.position.set(0, 0.02, 0); faucetGroup.add(fBase);
    // gooseneck rises, arcs toward the KITCHEN (-z) and comes back DOWN over the basin
    const gooseCurve = new THREE.CatmullRomCurve3([
      new THREE.Vector3(0, 0.04, 0),
      new THREE.Vector3(0, 0.42, 0),
      new THREE.Vector3(0, 0.54, -0.07),
      new THREE.Vector3(0, 0.55, -0.17),
      new THREE.Vector3(0, 0.48, -0.22),
      new THREE.Vector3(0, 0.33, -0.23),
      new THREE.Vector3(0, 0.24, -0.23),
    ]);
    const goose = new THREE.Mesh(new THREE.TubeGeometry(gooseCurve, 64, 0.022, 12, false), brass);
    goose.castShadow = true; goose.receiveShadow = true; faucetGroup.add(goose);
    const spoutTip = cyl(0.02, 0.016, 0.06, brass, 12); spoutTip.position.set(0, 0.21, -0.23); faucetGroup.add(spoutTip); // nozzle pointing down, toward the kitchen
    // single-lever mixer handle - inner end overlaps the stem so it stays glued
    const fLever = box(0.1, 0.018, 0.018, brass);
    fLever.position.set(0.05, 0.13, 0);
    fLever.rotation.z = 0.4;
    faucetGroup.add(fLever);
    island.add(faucetGroup);
    const drawers = [];
    [0.3, 0.55, 0.8].forEach((y, i) => {
      const dg = new THREE.Group(); dg.position.set(-0.7, y, ID / 2);
      const fr = box(1.3, 0.22, 0.04, charcoal);
      const dboxm = box(1.2, 0.18, 0.55, carcass); dboxm.position.set(0, 0, -0.3);
      const pl = box(1.05, 0.018, 0.03, brass); pl.position.set(0, 0.1, 0.03);
      dg.add(dboxm, fr, pl); dg.userData.openOffset = new THREE.Vector3();
      island.add(dg); drawers.push(dg); reg(dg, V(0, 0, -0.12), 0.2 + i * 0.08);
    });
    [0.5, 1.05].forEach((sx) => {
      const stool = new THREE.Group(); stool.position.set(sx, 0, 0.82);
      const seat = cyl(0.18, 0.18, 0.06, charcoal, 24); seat.position.y = 0.62;
      const stem2 = cyl(0.03, 0.035, 0.56, brass, 16); stem2.position.y = 0.31;
      const base = cyl(0.17, 0.17, 0.02, steel, 24); base.position.y = 0.02;
      stool.add(seat, stem2, base); island.add(stool);
    });
    reg(island, V(0, -0.5, 0), 0);

    /* hanging luxury pendant lights over the island */
    const pendants = new THREE.Group(); scene.add(pendants);
    const bulbMat = new THREE.MeshStandardMaterial({ color: 0x2a2a2a, emissive: 0xffdca8, emissiveIntensity: 3.0, roughness: 0.5 });
    [0.35, 1.05, 1.75].forEach((px) => {
      const pg = new THREE.Group(); pg.position.set(px, 0, 0.4);
      const cord = cyl(0.008, 0.008, 1.15, carcass, 8); cord.position.y = 2.32; pg.add(cord);          // ceiling -> housing
      const housing = cyl(0.02, 0.12, 0.2, brass, 20); housing.position.y = 1.72; pg.add(housing);     // sleek brass shade
      const bulb = new THREE.Mesh(new THREE.SphereGeometry(0.05, 16, 12), bulbMat); bulb.position.y = 1.6; bulb.castShadow = false; pg.add(bulb);
      const glow = new THREE.PointLight(0xffe2b0, 3.4, 6, 2); glow.position.set(0, 1.5, 0); glow.castShadow = false; pg.add(glow);
      pendants.add(pg);
    });
    reg(pendants, V(0, 0.5, 0), 0.45);

    /* ---------- camera choreography ---------- */
    // Camera framing - kitchen sits right-of-centre via aim (verticals stay straight),
    // text occupies the left column (CSS). Backed off on Z for a spacious, architectural look.
    const CAM = {
      a: { pos: V(4.2, 1.8, 6.8), tgt: V(1.0, 1.15, -0.2) },
      b: { pos: V(1.2, 2.6, 4.8), tgt: V(-0.6, 1.7, -2.6) },
    };
    let zPush = 0;
    // Dynamic aspect calibration: measure the real container every time and
    // match the renderer buffer + camera aspect exactly so nothing squishes.
    function resize() {
      const width = hero.clientWidth || canvas.clientWidth || window.innerWidth;
      const height = hero.clientHeight || canvas.clientHeight || window.innerHeight;
      if (!width || !height) return;
      renderer.setSize(width, height, false);          // buffer matches the CSS box (DPR applied)
      const aspect = width / height;
      camera.aspect = aspect;
      camera.fov = aspect >= 1.0 ? 34 : (aspect >= 0.7 ? 42 : 52); // compressed architectural FOV
      zPush = aspect >= 1.0 ? 0 : (aspect >= 0.7 ? 1.8 : 3.4);     // pull back on portrait
      camera.updateProjectionMatrix();
    }
    resize();

    /* ---------- interaction + loop ---------- */
    let mx = 0, my = 0, smx = 0, smy = 0;
    window.addEventListener("pointermove", (e) => {
      mx = (e.clientX / window.innerWidth) * 2 - 1;
      my = (e.clientY / window.innerHeight) * 2 - 1;
    }, { passive: true });
    const heroProgress = () => { const h = hero.offsetHeight || window.innerHeight; return clamp(window.scrollY / (h * 0.92), 0, 1); };

    const camPos = CAM.a.pos.clone(), camTgt = CAM.a.tgt.clone();
    const dPos = new THREE.Vector3(), dTgt = new THREE.Vector3();
    const t0 = performance.now(), INTRO = 1600;
    let faded = false, ready = false;

    function frame(now) {
      const t = now - t0;
      const introT = clamp(t / INTRO, 0, 1);
      const eIntro = easeOutCubic(introT);
      if (introT < 1) fadeMats.forEach((m) => { m.transparent = true; m.opacity = eIntro; });
      else if (!faded) { fadeMats.forEach((m) => { m.transparent = false; m.opacity = 1; }); faded = true; }

      const p = heroProgress();
      const e = easeInOut(p);
      smx = lerp(smx, mx, 0.05); smy = lerp(smy, my, 0.05);

      dPos.lerpVectors(CAM.a.pos, CAM.b.pos, e);
      dTgt.lerpVectors(CAM.a.tgt, CAM.b.tgt, e);
      dPos.x += smx * 0.6; dPos.y += -smy * 0.35; dPos.z += zPush;
      camPos.lerp(dPos, 0.055); camTgt.lerp(dTgt, 0.07);
      camera.position.copy(camPos); camera.lookAt(camTgt);

      drawers.forEach((dg, i) => { const o = clamp((p - i * 0.12) / 0.5, 0, 1); dg.userData.openOffset.z = easeInOut(o) * 0.4; });

      intro.forEach((it) => {
        const ss = easeOutCubic(clamp((introT - it.stagger) / 0.6, 0, 1));
        const off = it.obj.userData.openOffset;
        it.obj.position.set(
          it.home.x + it.from.x * (1 - ss) + (off ? off.x : 0),
          it.home.y + it.from.y * (1 - ss) + (off ? off.y : 0),
          it.home.z + it.from.z * (1 - ss) + (off ? off.z : 0)
        );
      });

      sun.position.x = -10 + smx * 1.2;
      renderer.render(scene, camera);
      if (!ready) { ready = true; hero.classList.add("is-3d-ready"); }
    }

    let raf = null, visible = true;
    const loop = (now) => { frame(now); raf = requestAnimationFrame(loop); };
    const start = () => { if (raf == null && visible) raf = requestAnimationFrame(loop); };
    const stop = () => { if (raf != null) { cancelAnimationFrame(raf); raf = null; } };
    start();
    if ("IntersectionObserver" in window) {
      new IntersectionObserver((es) => { visible = es[0].isIntersecting; visible ? start() : stop(); }, { threshold: 0 }).observe(canvas);
    }
    document.addEventListener("visibilitychange", () => { document.hidden ? stop() : start(); });
    let rt;
    const onResize = () => { clearTimeout(rt); rt = setTimeout(resize, 150); };
    window.addEventListener("resize", onResize);
    if ("ResizeObserver" in window) new ResizeObserver(onResize).observe(hero);
  }

  /* ---------- load-error banner (e.g. opened via file://) ---------- */
  function showLoadError() {
    const bar = el("div", {
      style:
        "position:fixed;inset:auto 0 0 0;z-index:999;background:#1c1916;color:#f6f1e8;" +
        "font-family:system-ui,sans-serif;padding:14px 18px;font-size:14px;text-align:center;" +
        "box-shadow:0 -2px 20px rgba(0,0,0,.4)",
    });
    bar.innerHTML =
      "Le contenu (content.json) n'a pas pu être chargé. " +
      "Ouvrez le site via un serveur local (par exemple <code>npx serve</code> ou " +
      "<code>python3 -m http.server</code>) plutôt qu'en double-cliquant le fichier.";
    document.body.appendChild(bar);
  }
})();
