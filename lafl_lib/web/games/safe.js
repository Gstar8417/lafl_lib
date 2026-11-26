// Safe: turn the dial (A D / wheel), the signal gets stronger near the number,
// press Space to set it. On medium / hard every number must be reached in the shown
// direction (right, left, right ...) and the exact number is only given away by a click
// (sound + small jolt of the dial), not by a green signal.
// opts: rounds (numbers), tolerance, range (signal range), mistakes, direction, green
LAFLGames.register('safe', {
    icon: '🔐',
    width: 520,
    presets: {
        easy:   { rounds: 3, tolerance: 1, range: 14, mistakes: 2, time: 90, direction: false, green: true },
        medium: { rounds: 3, tolerance: 0, range: 8,  mistakes: 1, time: 75, direction: true,  green: false },
        hard:   { rounds: 4, tolerance: 0, range: 6,  mistakes: 0, time: 75, direction: true,  green: false },
    },
    start(ctx) {
        const o = ctx.opts;
        let ticks = '';
        for (let i = 0; i < 100; i++) {
            const a = i * 3.6;
            const long = i % 5 === 0;
            ticks += `<line x1="130" y1="${long ? 34 : 38}" x2="130" y2="46" transform="rotate(${a} 130 130)" class="${long ? 'sf-tick long' : 'sf-tick'}"/>`;
            if (i % 10 === 0) ticks += `<text x="130" y="62" transform="rotate(${a} 130 130)" class="sf-num">${i}</text>`;
        }
        let bars = '';
        for (let i = 0; i < 6; i++) bars += `<i style="height:${14 + i * 9}px"></i>`;

        ctx.root.innerHTML = `
            <div class="sf">
                <div class="sf-dial-wrap">
                    <div class="sf-pointer"></div>
                    <svg viewBox="0 0 260 260" width="260" height="260">
                        <circle cx="130" cy="130" r="118" class="sf-ring"/>
                        <g class="sf-dial">${ticks}<circle cx="130" cy="130" r="56" class="sf-knob"/><rect x="126" y="80" width="8" height="34" rx="4" class="sf-grip"/></g>
                        <circle cx="130" cy="130" r="20" class="sf-cap"/>
                    </svg>
                </div>
                <div class="sf-side">
                    <div class="label">${ctx.esc(ctx.L('safe_signal'))}</div>
                    <div class="sf-bars">${bars}</div>
                    <div class="sf-value">00</div>
                    <div class="sf-dir"></div>
                    <div class="sf-slots"></div>
                </div>
            </div>`;

        const dial = ctx.root.querySelector('.sf-dial');
        const barEls = ctx.root.querySelectorAll('.sf-bars i');
        const valueEl = ctx.root.querySelector('.sf-value');
        const slotsEl = ctx.root.querySelector('.sf-slots');
        const dirEl = ctx.root.querySelector('.sf-dir');
        const wrap = ctx.root.querySelector('.sf-dial-wrap');

        // combination with clear gaps between the numbers
        const combo = [];
        while (combo.length < o.rounds) {
            const n = LAFLGames.randInt(0, 99);
            const prev = combo.length ? combo[combo.length - 1] : (n + 50) % 100;
            const d = Math.abs(n - prev);
            if (Math.min(d, 100 - d) >= 15) combo.push(n);
        }

        let value = 0, shown = 0, index = 0, mistakes = 0, wasOn = false, lastDir = 0, ready = false;
        const needDir = () => (index % 2 === 0 ? 1 : -1);    // right, left, right ...

        function showDir(wrong) {
            if (!o.direction) { dirEl.textContent = ''; return; }
            dirEl.className = 'sf-dir' + (wrong ? ' bad' : '');
            dirEl.textContent = wrong ? ctx.L('safe_wrong_dir') : (needDir() > 0 ? '⟳ ' + ctx.L('safe_right') : '⟲ ' + ctx.L('safe_left'));
        }

        function jolt() {
            wrap.classList.remove('click');
            void wrap.offsetWidth;
            wrap.classList.add('click');
        }

        const dist = (a, b) => { const d = Math.abs(a - b); return Math.min(d, 100 - d); };
        const stats = () => ctx.stats(ctx.round(index + 1) + (o.mistakes > 0 ? ctx.pill(`${ctx.L('mg_mistakes')} ${mistakes}/${o.mistakes}`, mistakes ? 'warn' : 'mute') : ''));

        function slots() {
            slotsEl.innerHTML = combo.map((n, i) => `<span class="sf-slot${i < index ? ' set' : ''}${i === index ? ' cur' : ''}">${i < index ? String(n).padStart(2, '0') : '··'}</span>`).join('');
        }

        function update() {
            const d = dist(value, combo[index]);
            const on = d <= o.tolerance;
            // without green: full signal already one step before / after, only the click tells the exact number
            const full = o.green ? on : d <= 1;
            const strength = full ? 1 : Math.max(0, 1 - d / o.range);
            const lit = full ? barEls.length : Math.floor(strength * (barEls.length - 1));
            barEls.forEach((b, i) => { b.className = i < lit ? (on && o.green ? 'on hit' : 'on') : ''; });
            valueEl.textContent = String(value).padStart(2, '0');
            valueEl.classList.toggle('hit', on && o.green);
            if (!ready) return;
            if (on && !wasOn) { ctx.sound(1400, 35, 'square', 0.035); jolt(); }
            else ctx.sound(900 + strength * 500, 12, 'square', 0.006 + strength * 0.01);
            wasOn = on;
        }

        function turn(step) {
            value = (value + step + 100) % 100;
            shown += step;
            if (ready && step) lastDir = step > 0 ? 1 : -1;
            dial.setAttribute('transform', `rotate(${-shown * 3.6} 130 130)`);
            update();
        }

        function set() {
            if (!ready) return;
            const rightDir = !o.direction || lastDir === needDir();
            if (rightDir && dist(value, combo[index]) <= o.tolerance) {
                index++;
                lastDir = 0;
                showDir(false);
                ctx.sound(700, 60); setTimeout(() => ctx.sound(1050, 90), 70);
                slots();
                if (index >= combo.length) return ctx.win();
                stats();
                update();
            } else {
                mistakes++;
                if (!rightDir) { showDir(true); setTimeout(() => showDir(false), 900); }
                ctx.sound(170, 140, 'square', 0.03);
                ctx.shake();
                stats();
                if (mistakes > o.mistakes) ctx.fail();
            }
        }

        // keys: one step per press; held keys keep turning (does not rely on key repeat)
        const held = { left: false, right: false, shift: false };
        let holdTime = 0, stepTimer = 0;
        const dirOf = k => (k === 'a' || k === 'arrowleft') ? 'left' : (k === 'd' || k === 'arrowright') ? 'right' : null;

        const onDown = e => {
            const k = LAFLGames.key(e);
            if (k === 'shift') { held.shift = true; return; }
            const dir = dirOf(k);
            if (dir) {
                if (!held[dir]) { held[dir] = true; holdTime = 0; stepTimer = 0; turn((dir === 'left' ? -1 : 1) * (held.shift || e.shiftKey ? 5 : 1)); }
                return;
            }
            if ((k === ' ' || k === 'enter' || k === 'e') && !e.repeat) set();
        };
        const onUp = e => {
            const k = LAFLGames.key(e);
            if (k === 'shift') { held.shift = false; return; }
            const dir = dirOf(k);
            if (dir) held[dir] = false;
        };
        const onWheel = e => { e.preventDefault(); turn(e.deltaY > 0 ? 1 : -1); };
        window.addEventListener('keydown', onDown);
        window.addEventListener('keyup', onUp);
        window.addEventListener('wheel', onWheel, { passive: false });

        ctx.loop(dt => {
            const dir = held.left && !held.right ? -1 : held.right && !held.left ? 1 : 0;
            if (!dir) return;
            holdTime += dt;
            if (holdTime < 0.3) return;                 // short delay like a normal key repeat
            stepTimer -= dt;
            if (stepTimer <= 0) {
                turn(dir * (held.shift ? 5 : 1));
                stepTimer = held.shift ? 0.09 : 0.06;
            }
        });

        // start somewhere away from the first number
        turn(LAFLGames.randInt(0, 99));
        ready = true;
        wasOn = dist(value, combo[0]) <= o.tolerance;
        slots();
        stats();
        showDir(false);

        return () => {
            window.removeEventListener('keydown', onDown);
            window.removeEventListener('keyup', onUp);
            window.removeEventListener('wheel', onWheel);
        };
    },
});
