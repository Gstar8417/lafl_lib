// =====================================================================
//  lafl_lib overlay: notify, progress, text UI, minigame frame
// =====================================================================

(function () {
    const UI = window.LAFLUI;
    const $ = id => document.getElementById(id);
    let cfg = { notify: {}, progress: {}, textui: {}, sounds: true };

    UI.on('init', data => {
        cfg = data;
        UI.setup({ locale: data.locale, lang: data.lang, ui: data.ui });
        $('notify').className = (data.notify && data.notify.position) || 'center-right';
        $('textui').className = 'hidden ' + ((data.textui && data.textui.position) || 'center-left');
        if (data.progress && data.progress.position === 'center') $('progress').classList.add('center');
    });

    const sound = (...a) => { if (cfg.sounds !== false) UI.beep(...a); };

    // -----------------------------------------------------------------
    //  Notify
    // -----------------------------------------------------------------
    const ICONS = { inform: 'i', success: '✓', error: '✕', warning: '!' };
    const live = [];   // { el, key, count, timer }

    /**
     * Small formatting: **bold**, line breaks and the GTA codes other scripts send
     * (~r~ red, ~g~ green, ~b~ blue, ~y~ yellow, ~o~ orange, ~p~ purple, ~c~ grey,
     *  ~s~ / ~w~ back to normal, ~h~ bold, ~n~ / ~br~ new line). Other ~...~ tokens are removed.
     */
    const GTA = { r: '#ef5b4c', g: '#5fd38d', b: '#5aa9e6', y: '#f0d34a', o: '#f0a63a', p: '#b38cf0', c: '#9aa294', m: '#6d7468', u: '#9aa294', q: '#e889c4' };
    function richText(text) {
        let out = '', open = 0;
        const close = () => { const s = '</span>'.repeat(open); open = 0; return s; };
        const parts = String(text ?? '').split(/(~[^~\s]{1,24}~|\n)/);
        for (const part of parts) {
            if (part === '\n' || part === '~n~' || part === '~br~') { out += '<br>'; continue; }
            const m = /^~([^~\s]+)~$/.exec(part);
            if (m) {
                const c = m[1];
                if (GTA[c]) { out += close() + `<span style="color:${GTA[c]}">`; open++; }
                else if (c === 's' || c === 'w') out += close();
                else if (c === 'h') { out += '<span style="font-weight:700">'; open++; }
                continue;   // ~INPUT_CONTEXT~, ~a~ ... are dropped
            }
            out += UI.esc(part).replace(/\*\*(.+?)\*\*/g, '<b>$1</b>');
        }
        return out + close();
    }

    function removeNotify(n) {
        const i = live.indexOf(n);
        if (i !== -1) live.splice(i, 1);
        n.el.classList.add('out');
        setTimeout(() => n.el.remove(), 200);
    }

    function startTimer(n, duration) {
        clearTimeout(n.timer);
        const bar = n.el.querySelector('.nt-bar i');
        bar.style.animation = 'none';
        void bar.offsetWidth;
        bar.style.animation = '';
        bar.style.animationDuration = duration + 'ms';
        n.timer = setTimeout(() => removeNotify(n), duration);
    }

    UI.on('notify', d => {
        const type = ['inform', 'success', 'error', 'warning'].includes(d.type) ? d.type : 'inform';
        const duration = Math.max(1000, Number(d.duration) || 5000);
        const key = type + '|' + (d.title || '') + '|' + d.message;

        // same text again -> counter instead of a new card
        const same = live.find(n => n.key === key);
        if (same) {
            same.count++;
            let c = same.el.querySelector('.nt-count');
            if (!c) {
                c = document.createElement('span');
                c.className = 'nt-count';
                const host = same.el.querySelector('.nt-title') || same.el.querySelector('.nt-msg');
                host.appendChild(c);
            }
            c.textContent = '×' + same.count;
            startTimer(same, duration);
            return;
        }

        const el = document.createElement('div');
        el.className = 'nt ' + type;
        const emoji = d.icon && d.icon.length <= 4;
        el.innerHTML = `
            <div class="nt-ico${emoji ? ' emoji' : ''}">${UI.esc(emoji ? d.icon : ICONS[type])}</div>
            <div>
                ${d.title ? `<div class="nt-title">${UI.esc(d.title)}</div>` : ''}
                <div class="nt-msg">${richText(d.message)}</div>
            </div>
            <div class="nt-bar"><i></i></div>`;
        $('notify').appendChild(el);

        const n = { el, key, count: 1 };
        live.push(n);
        startTimer(n, duration);

        const max = (cfg.notify && cfg.notify.maxVisible) || 5;
        while (live.length > max) removeNotify(live[0]);

        if (cfg.notify && cfg.notify.sound !== false && cfg.sounds !== false) {
            if (type === 'error') UI.beep(220, 120, 'triangle', 0.04);
            else if (type === 'success') UI.beep(880, 80, 'sine', 0.035);
            else UI.beep(620, 60, 'sine', 0.03);
        }
    });

    // -----------------------------------------------------------------
    //  Progress
    // -----------------------------------------------------------------
    let pgFrame = null;

    UI.on('progress', d => {
        const el = $('progress');
        cancelAnimationFrame(pgFrame);
        el.classList.remove('hidden', 'done', 'fail');
        el.querySelector('.pg-label').textContent = d.label || '';
        const hint = el.querySelector('.pg-hint');
        hint.classList.toggle('hidden', !d.cancel);
        hint.querySelector('span:last-child').textContent = d.cancel || '';
        const bar = el.querySelector('.pg-bar i');
        const pct = el.querySelector('.pg-pct');
        const start = performance.now();
        const step = now => {
            const p = Math.min(1, (now - start) / d.duration);
            bar.style.width = (p * 100) + '%';
            pct.textContent = Math.floor(p * 100) + '%';
            if (p < 1) pgFrame = requestAnimationFrame(step);
        };
        pgFrame = requestAnimationFrame(step);
    });

    UI.on('progressEnd', (_, msg) => {
        const el = $('progress');
        cancelAnimationFrame(pgFrame);
        el.classList.add(msg.ok ? 'done' : 'fail');
        if (msg.ok) { el.querySelector('.pg-bar i').style.width = '100%'; el.querySelector('.pg-pct').textContent = '100%'; }
        setTimeout(() => el.classList.add('hidden'), msg.ok ? 250 : 600);
    });

    // -----------------------------------------------------------------
    //  Text UI
    // -----------------------------------------------------------------
    UI.on('textui', d => {
        const el = $('textui');
        const keyEl = el.querySelector('.tu-key');
        keyEl.textContent = d.key || '';
        keyEl.classList.toggle('hidden', !d.key);        // key = false: text only
        const ico = el.querySelector('.tu-ico');
        ico.textContent = d.icon || '';
        ico.classList.toggle('hidden', !d.icon);
        el.querySelector('.tu-text').innerHTML = richText(d.text || '');
        el.classList.remove('hidden');
    });
    UI.on('textuiHide', () => $('textui').classList.add('hidden'));

    // -----------------------------------------------------------------
    //  3D text: one message per frame with all labels on screen
    //  items: [{ id, x, y (0..1), s (scale), o (opacity), parts: [{ k, t }] }]
    // -----------------------------------------------------------------
    const labels = new Map();   // id -> element
    function buildLabel(parts) {
        const el = document.createElement('div');
        el.className = 'l3';
        const box = document.createElement('div');
        box.className = 'l3-box';
        let keys = 0;
        parts.forEach((p, i) => {
            if (i > 0) box.insertAdjacentHTML('beforeend', '<span class="l3-sep"></span>');
            if (p.k) box.insertAdjacentHTML('beforeend', `<span class="l3-k${keys++ ? ' alt' : ''}">${UI.esc(p.k)}</span>`);
            box.insertAdjacentHTML('beforeend', `<span class="l3-t">${richText(p.t || '')}</span>`);
        });
        if (!keys) box.classList.add('plain');
        el.appendChild(box);
        el.insertAdjacentHTML('beforeend', '<div class="l3-stem"></div><div class="l3-dot"></div>');
        $('text3d').appendChild(el);
        return el;
    }
    UI.on('text3d', (_, msg) => {
        const items = msg.items || [];
        const keep = new Set();
        const w = window.innerWidth, h = window.innerHeight;
        for (const it of items) {
            keep.add(it.id);
            let el = labels.get(it.id);
            if (!el) { el = buildLabel(it.parts || []); labels.set(it.id, el); }
            el.style.transform = `translate(${(it.x * w).toFixed(1)}px, ${(it.y * h).toFixed(1)}px) translate(-50%, -100%) scale(${it.s.toFixed(3)})`;
            el.style.opacity = it.o.toFixed(2);
        }
        for (const [id, el] of labels) if (!keep.has(id)) { el.remove(); labels.delete(id); }
    });

    // -----------------------------------------------------------------
    //  Clipboard (coordinate commands)
    // -----------------------------------------------------------------
    UI.on('copy', (_, msg) => {
        const ta = document.createElement('textarea');
        ta.value = msg.text;
        document.body.appendChild(ta);
        ta.select();
        try { document.execCommand('copy'); } catch (e) { /* ignore */ }
        ta.remove();
    });

    // -----------------------------------------------------------------
    //  Minigame frame
    // -----------------------------------------------------------------
    const games = {};
    let current = null;

    /**
     * Register a game.
     * def = { icon, width, presets: { easy, medium, hard }, start(ctx) -> cleanup fn }
     */
    function register(name, def) { games[name] = def; }

    function setStats(html) { $('mg-stats').innerHTML = html; }

    function end(success, reason) {
        if (!current || current.ended) return;
        const run = current;
        run.ended = true;
        clearInterval(run.timerId);
        const box = $('mg-result');
        box.className = 'mg-result' + (success ? '' : ' fail');
        box.innerHTML = `<div>${UI.esc(success ? UI.L('mg_success') : UI.L('mg_fail'))}${reason ? `<small>${UI.esc(reason)}</small>` : ''}</div>`;
        if (success) { sound(660, 90); setTimeout(() => sound(990, 140), 90); }
        else { sound(180, 260, 'sawtooth', 0.04); $('mg-window').classList.add('shake'); }
        setTimeout(() => {
            try { run.cleanup && run.cleanup(); } catch (e) { console.error(e); }
            if (current === run) {
                // only close if no other game was started in the meantime
                $('minigame').classList.add('hidden');
                $('mg-window').classList.remove('shake');
                current = null;
            }
            if (!run.silent) UI.post('minigameResult', { success });
        }, success ? 700 : 1100);
    }

    function startGame(name, opts = {}) {
        const def = games[name];
        if (!def) { UI.post('minigameResult', { success: false }); return; }
        if (current) { current.silent = true; current.ended = true; try { current.cleanup && current.cleanup(); } catch (e) { /* ignore */ } }

        const difficulty = def.presets[opts.difficulty] ? opts.difficulty : 'medium';
        const o = Object.assign({}, def.presets[difficulty], opts);
        o.rounds = Math.max(1, Math.floor(o.rounds || 1));

        const win = $('mg-window');
        win.style.width = (def.width || 560) + 'px';
        // take the keyboard focus (e.g. away from the chat input the command was typed in)
        try { if (document.activeElement && document.activeElement.blur) document.activeElement.blur(); } catch (e) { /* ignore */ }
        try { window.focus(); win.setAttribute('tabindex', '-1'); win.focus({ preventScroll: true }); } catch (e) { /* ignore */ }
        if (opts.accent) UI.theme({ accent: opts.accent, accentText: opts.accentText }, win);
        else { win.style.removeProperty('--accent'); win.style.removeProperty('--accent-soft'); win.style.removeProperty('--accent-ink'); }

        $('mg-logo').textContent = opts.icon || def.icon;
        $('mg-title').textContent = opts.title || UI.L(name + '_title');
        $('mg-sub').textContent = opts.subtitle || UI.L(name + '_sub');
        $('mg-hint').textContent = opts.hint || UI.L(name + '_hint');
        $('mg-esc').textContent = UI.L('mg_abort');
        $('mg-result').className = 'mg-result hidden';
        setStats('');
        const body = $('mg-body');
        body.innerHTML = '';
        $('minigame').classList.remove('hidden');

        const run = { name, ended: false, cleanup: null, timerId: null, started: performance.now() };
        current = run;

        const timer = $('mg-timer');
        const ctx = {
            root: body,
            opts: o,
            L: UI.L,
            esc: UI.esc,
            sound,
            win: () => { if (current === run) end(true); },
            fail: reason => { if (current === run) end(false, reason); },
            stats: setStats,
            pill: (text, cls = '') => `<span class="pill ${cls}">${UI.esc(text)}</span>`,
            round: (i) => `<span class="pill">${UI.esc(UI.L('mg_round'))} ${i}/${o.rounds}</span>`,
            shake: () => { win.classList.remove('shake'); void win.offsetWidth; win.classList.add('shake'); },
            get ended() { return run.ended; },
            // rAF loop that stops automatically
            loop(fn) {
                let last = performance.now();
                const tick = now => {
                    if (run.ended || current !== run) return;
                    const dt = Math.min(0.05, (now - last) / 1000);
                    last = now;
                    fn(dt, now);
                    requestAnimationFrame(tick);
                };
                requestAnimationFrame(tick);
            },
            // pause / resume the total timer (e.g. while showing a pattern)
            pauseTimer(p) { run.paused = p; },
        };

        // total time limit (opts.time in seconds, 0 = none)
        const total = Number(o.time) || 0;
        timer.classList.toggle('hidden', total <= 0);
        timer.classList.remove('low');
        if (total > 0) {
            let left = total * 1000;
            const bar = timer.querySelector('i');
            bar.style.transform = 'scaleX(1)';
            let last = performance.now();
            run.timerId = setInterval(() => {
                const now = performance.now();
                if (!run.paused) left -= now - last;
                last = now;
                bar.style.transform = `scaleX(${Math.max(0, left / (total * 1000))})`;
                timer.classList.toggle('low', left < total * 250);
                if (left <= 0) end(false, UI.L('mg_timeout'));
            }, 50);
        }

        try {
            run.cleanup = def.start(ctx);
        } catch (e) {
            console.error('[lafl_lib] minigame error', e);
            end(false);
        }
    }

    UI.on('minigame', (_, msg) => startGame(msg.game, msg.opts || {}));

    // -----------------------------------------------------------------
    //  Keyboard compatibility for FiveM's NUI
    //  Some setups deliver letters only as 'keypress' (character) or only as
    //  'keyup'. Those are turned into normal keydown / keyup events here, so
    //  every game only has to listen to keydown / keyup.
    // -----------------------------------------------------------------
    const realDown = {};   // key -> true while a real keydown is held
    const synth = {};      // key -> release timer of a key that came without keydown

    function fire(type, key, repeat) {
        const ev = new KeyboardEvent(type, { key, repeat: !!repeat, bubbles: true });
        ev.__lafl = true;
        window.dispatchEvent(ev);
    }

    function debugKey(type, e, synthetic) {
        if (!cfg.debug || !current) return;
        UI.post('debugKey', { type, key: e.key, code: e.code, keyCode: e.keyCode || e.which || e.charCode, synthetic });
    }

    window.addEventListener('keydown', e => {
        if (e.__lafl) return;
        debugKey('down', e);
        const k = UI.key(e);
        if (k) realDown[k] = true;
    }, true);

    window.addEventListener('keypress', e => {
        if (e.__lafl) return;
        let k = UI.key(e);
        if (!k || k === 'unidentified') k = String.fromCharCode(e.charCode || e.keyCode || 0).toLowerCase();
        if (!k || realDown[k]) { debugKey('press', e); return; }
        debugKey('press', e, true);
        const held = synth[k] !== undefined;
        clearTimeout(synth[k]);
        fire('keydown', k, held);
        synth[k] = setTimeout(() => { delete synth[k]; fire('keyup', k); }, 220);
    }, true);

    window.addEventListener('keyup', e => {
        if (e.__lafl) return;
        const k = UI.key(e);
        if (realDown[k]) { delete realDown[k]; debugKey('up', e); return; }
        if (synth[k] !== undefined) {          // came as keypress: release now
            clearTimeout(synth[k]); delete synth[k];
            debugKey('up', e);
            fire('keyup', k);
            e.stopImmediatePropagation();
            return;
        }
        // only a keyup arrived: count it as a full press – but not right after the start
        // (e.g. the Enter of the chat command that opened the game) and never for Enter / Escape
        if (!current || performance.now() - current.started < 700 || k === 'enter' || k === 'escape') { debugKey('up', e); return; }
        debugKey('up', e, true);
        if (k) fire('keydown', k, false);
    }, true);
    window.addEventListener('blur', () => { for (const k in realDown) delete realDown[k]; });
    UI.on('minigameStop', () => {
        if (!current) return;
        current.silent = true;
        current.ended = true;
        clearInterval(current.timerId);
        try { current.cleanup && current.cleanup(); } catch (e) { /* ignore */ }
        current = null;
        $('minigame').classList.add('hidden');
    });

    window.addEventListener('keydown', e => {
        if (UI.key(e) === 'escape' && current && !current.ended) end(false);
    });

    // helpers for the games
    window.LAFLGames = {
        register,
        key: UI.key,
        rand: (a, b) => a + Math.random() * (b - a),
        randInt: (a, b) => Math.floor(a + Math.random() * (b - a + 1)),
        shuffle(arr) { for (let i = arr.length - 1; i > 0; i--) { const j = Math.floor(Math.random() * (i + 1)); [arr[i], arr[j]] = [arr[j], arr[i]]; } return arr; },
        // preview helper for development in a normal browser
        _start: startGame,
    };

    // tell the client script that the page is ready
    // (retry, in case the page loads before the client script registered its callback)
    window.addEventListener('load', async () => {
        if (typeof GetParentResourceName !== 'function') return;   // browser preview
        for (let i = 0; i < 40; i++) {
            if (await UI.post('ready') !== null) return;
            await new Promise(r => setTimeout(r, 500));
        }
    });
})();
