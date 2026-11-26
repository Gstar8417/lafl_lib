// Keypad: find the code. After every try each digit shows
// green (right place), yellow (in the code, wrong place) or grey (not in the code).
// opts: rounds, length, tries, unique (no repeated digits), code ('4711' = fixed code), feedback (false = no colors)
LAFLGames.register('keypad', {
    icon: '🔢',
    width: 540,
    presets: {
        easy:   { rounds: 1, length: 3, tries: 8, unique: true,  time: 90 },
        medium: { rounds: 1, length: 4, tries: 7, unique: true,  time: 90 },
        hard:   { rounds: 1, length: 5, tries: 7, unique: false, time: 100 },
    },
    start(ctx) {
        const o = ctx.opts;
        const fixed = o.code !== undefined && o.code !== null && String(o.code).length > 0;
        const len = fixed ? String(o.code).length : Math.max(2, Math.min(8, o.length));
        const feedback = o.feedback !== false;

        let keys = '';
        ['1', '2', '3', '4', '5', '6', '7', '8', '9', 'del', '0', 'ok'].forEach(k => {
            const label = k === 'del' ? '⌫' : k === 'ok' ? '✓' : k;
            keys += `<button class="kp-key${k === 'ok' ? ' ok' : ''}${k === 'del' ? ' del' : ''}" data-k="${k}">${label}</button>`;
        });
        ctx.root.innerHTML = `
            <div class="kp">
                <div class="kp-left">
                    <div class="kp-display"></div>
                    <div class="kp-history scroll"></div>
                    ${feedback ? `<div class="g-sub">${ctx.esc(ctx.L('keypad_hint_fb'))}</div>` : ''}
                </div>
                <div class="kp-pad">${keys}</div>
            </div>`;
        const display = ctx.root.querySelector('.kp-display');
        const history = ctx.root.querySelector('.kp-history');

        let round = 1, code = '', input = '', tries = 0, locked = false;

        function newCode() {
            if (fixed) { code = String(o.code); return; }
            const digits = [];
            while (digits.length < len) {
                const d = String(LAFLGames.randInt(0, 9));
                if (!o.unique || !digits.includes(d)) digits.push(d);
            }
            code = digits.join('');
        }

        const stats = () => ctx.stats(ctx.round(round) + ctx.pill(`${ctx.L('keypad_tries')} ${o.tries - tries}`, o.tries - tries <= 2 ? 'warn' : 'mute'));

        function render() {
            let html = '';
            for (let i = 0; i < len; i++) html += `<span class="${i === input.length ? 'cur' : ''}">${input[i] || ''}</span>`;
            display.innerHTML = html;
        }

        function score(guess) {
            const res = Array(len).fill('no');
            const rest = {};
            for (let i = 0; i < len; i++) {
                if (guess[i] === code[i]) res[i] = 'yes';
                else rest[code[i]] = (rest[code[i]] || 0) + 1;
            }
            for (let i = 0; i < len; i++) {
                if (res[i] !== 'yes' && rest[guess[i]] > 0) { res[i] = 'near'; rest[guess[i]]--; }
            }
            return res;
        }

        function submit() {
            if (locked || input.length < len) { ctx.sound(220, 60, 'square', 0.02); return; }
            tries++;
            const res = score(input);
            const row = document.createElement('div');
            row.className = 'kp-row';
            row.innerHTML = input.split('').map((d, i) => `<span class="${feedback ? res[i] : (input === code ? 'yes' : 'no')}">${d}</span>`).join('');
            history.prepend(row);
            const guess = input;
            input = '';
            render();
            stats();

            if (guess === code) {
                ctx.sound(880, 80);
                if (round >= o.rounds) { locked = true; return ctx.win(); }
                round++;
                tries = 0;
                history.innerHTML = '';
                newCode();
                stats();
                return;
            }
            ctx.sound(240, 110, 'square', 0.03);
            ctx.shake();
            if (tries >= o.tries) { locked = true; ctx.fail(); }
        }

        function press(k) {
            if (locked) return;
            if (k === 'ok') return submit();
            if (k === 'del') { input = input.slice(0, -1); render(); return; }
            if (input.length < len) { input += k; ctx.sound(600 + Number(k) * 30, 30, 'sine', 0.025); render(); }
        }

        ctx.root.querySelectorAll('.kp-key').forEach(b => b.addEventListener('click', () => press(b.dataset.k)));
        const onKey = e => {
            const k = LAFLGames.key(e);
            if (/^[0-9]$/.test(k)) press(k);
            else if (k === 'backspace') press('del');
            else if (k === 'enter') press('ok');
        };
        window.addEventListener('keydown', onKey);

        newCode();
        render();
        stats();
        return () => window.removeEventListener('keydown', onKey);
    },
});
