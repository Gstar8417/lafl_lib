// =====================================================================
//  LAFL UI-Kit (JS) – shared helpers for all LAFL menus
//  <script src="nui://lafl_lib/web/lafl.js"></script>  ->  window.LAFLUI
// =====================================================================

(function () {
    const resource = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'lafl_lib';

    let locale = {};
    let lang = 'en';
    let currency = '$';
    let imagePath = false;

    /** POST to the client script of this resource, returns the JSON answer (or null) */
    async function post(name, body = {}) {
        try {
            const res = await fetch(`https://${resource}/${name}`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json; charset=UTF-8' },
                body: JSON.stringify(body),
            });
            return await res.json();
        } catch (e) {
            return null;
        }
    }

    /** Escape text for innerHTML */
    function esc(text) {
        return String(text ?? '').replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]);
    }

    /** '#e8b84a' -> 'rgba(232, 184, 74, a)' */
    function rgba(hex, a) {
        const h = String(hex).replace('#', '');
        const full = h.length === 3 ? h.split('').map(c => c + c).join('') : h;
        const n = parseInt(full, 16);
        if (Number.isNaN(n)) return `rgba(232, 184, 74, ${a})`;
        return `rgba(${(n >> 16) & 255}, ${(n >> 8) & 255}, ${n & 255}, ${a})`;
    }

    /** Apply the accent color: { accent, accentText } */
    function theme(t = {}, el = document.documentElement) {
        if (t.accent) {
            el.style.setProperty('--accent', t.accent);
            el.style.setProperty('--accent-soft', rgba(t.accent, 0.13));
        }
        if (t.accentText) el.style.setProperty('--accent-ink', t.accentText);
    }

    /** Settings sent by the script: { locale, lang, currency, imagePath, ui } */
    function setup(cfg = {}) {
        if (cfg.locale) locale = cfg.locale;
        if (cfg.lang) lang = cfg.lang;
        if (cfg.currency) currency = cfg.currency;
        if (cfg.imagePath !== undefined) imagePath = cfg.imagePath;
        if (cfg.ui) theme(cfg.ui);
    }

    const L = key => (locale[key] ?? '');
    const fmt = (key, ...vals) => { let i = 0; return L(key).replace(/%%|%[ds]/g, m => (m === '%%' ? '%' : vals[i++])); };

    /** 12500 -> '12.500 $' (de) or '$12,500' (en) */
    function money(n) {
        const num = Math.floor(Number(n) || 0).toLocaleString(lang === 'de' ? 'de-DE' : 'en-US');
        return lang === 'de' ? `${num} ${currency}` : `${currency}${num}`;
    }

    function number(n) {
        return Math.floor(Number(n) || 0).toLocaleString(lang === 'de' ? 'de-DE' : 'en-US');
    }

    /** 75 -> '1:15', 3700 -> '1:01:40', < 60 -> '45 s' */
    function time(sec) {
        sec = Math.max(0, Math.round(sec));
        if (sec < 60) return sec + ' s';
        const h = Math.floor(sec / 3600), m = Math.floor(sec % 3600 / 60), s = sec % 60;
        return h ? `${h}:${String(m).padStart(2, '0')}:${String(s).padStart(2, '0')}` : `${m}:${String(s).padStart(2, '0')}`;
    }

    /** Inventory image with emoji fallback */
    function icon(item, emoji = '📦') {
        if (imagePath && item) {
            return `<img src="${esc(imagePath.replace('%s', item))}" data-fallback="${esc(emoji)}" alt="">`;
        }
        return esc(emoji);
    }
    document.addEventListener('error', ev => {
        const img = ev.target;
        if (img && img.tagName === 'IMG' && img.dataset.fallback !== undefined) {
            img.replaceWith(document.createTextNode(img.dataset.fallback));
        }
    }, true);

    /**
     * Name of the pressed key, lower case: 'e', 'a', '5', ' ', 'enter', 'escape', 'arrowleft' ...
     * FiveM's NUI often sends letters without e.key ('Unidentified'), so keyCode and code are used as fallback.
     */
    const CODES = { 8: 'backspace', 9: 'tab', 13: 'enter', 16: 'shift', 17: 'control', 18: 'alt', 27: 'escape', 32: ' ',
        37: 'arrowleft', 38: 'arrowup', 39: 'arrowright', 40: 'arrowdown', 46: 'delete' };
    function key(e) {
        const k = e.key, code = e.code || '';
        // named keys: 'Enter', 'Escape', 'ArrowLeft', 'Shift' ...
        if (k && k.length > 1 && k !== 'Unidentified' && k !== 'Dead') return k.toLowerCase();
        // normal latin letters, digits, space
        if (k && k.length === 1 && /^[a-z0-9 ]$/i.test(k)) return k.toLowerCase();
        // no key or another keyboard layout (e.g. Cyrillic 'в' on the D key):
        // keyCode (keydown / keyup only – keypress has char codes there), then the key position
        if (e.type !== 'keypress') {
            const c = e.keyCode || e.which || 0;
            if (c >= 65 && c <= 90) return String.fromCharCode(c).toLowerCase();
            if (c >= 48 && c <= 57) return String.fromCharCode(c);
            if (c >= 96 && c <= 105) return String(c - 96);
            if (CODES[c]) return CODES[c];
        }
        if (code.startsWith('Key')) return code.slice(3).toLowerCase();
        if (code.startsWith('Digit')) return code.slice(5);
        if (code.startsWith('Numpad') && /\d$/.test(code)) return code.slice(-1);
        if (code === 'Space') return ' ';
        if (e.type === 'keypress') {
            const ch = String.fromCharCode(e.charCode || e.keyCode || 0);
            if (/^[a-z0-9 ]$/i.test(ch)) return ch.toLowerCase();
        }
        if (k && k.length === 1) return k.toLowerCase();
        return code.toLowerCase();
    }

    /** ESC handler (e.g. close the menu) */
    function onEscape(fn) {
        window.addEventListener('keydown', e => { if (key(e) === 'escape') fn(e); });
    }

    /** Route NUI messages: LAFLUI.on('open', data => ...) */
    const handlers = {};
    function on(action, fn) { handlers[action] = fn; }
    window.addEventListener('message', e => {
        const msg = e.data || {};
        if (msg.action && handlers[msg.action]) handlers[msg.action](msg.data ?? msg, msg);
    });

    /** Small sounds without files (WebAudio) */
    let audio = null;
    function beep(freq = 660, ms = 70, type = 'sine', vol = 0.05) {
        try {
            audio = audio || new (window.AudioContext || window.webkitAudioContext)();
            const o = audio.createOscillator(), g = audio.createGain();
            o.type = type; o.frequency.value = freq;
            g.gain.setValueAtTime(vol, audio.currentTime);
            g.gain.exponentialRampToValueAtTime(0.0001, audio.currentTime + ms / 1000);
            o.connect(g); g.connect(audio.destination);
            o.start(); o.stop(audio.currentTime + ms / 1000 + 0.02);
        } catch (e) { /* no audio */ }
    }

    window.LAFLUI = { resource, post, esc, rgba, theme, setup, L, fmt, money, number, time, icon, key, onEscape, on, beep,
        get lang() { return lang; }, get locale() { return locale; } };
})();
