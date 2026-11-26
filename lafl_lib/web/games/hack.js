// Hack: numbers are shown for a short time, then click them in order (1, 2, 3 ...).
// opts: rounds, numbers (first round, +1 per round), show (seconds), mistakes, cols, rows
LAFLGames.register('hack', {
    icon: '💻',
    width: 520,
    presets: {
        easy:   { rounds: 2, numbers: 5, show: 4.0, mistakes: 1, cols: 6, rows: 4, time: 45 },
        medium: { rounds: 3, numbers: 6, show: 3.5, mistakes: 0, cols: 6, rows: 4, time: 50 },
        hard:   { rounds: 3, numbers: 8, show: 3.0, mistakes: 0, cols: 7, rows: 4, time: 50 },
    },
    start(ctx) {
        const o = ctx.opts;
        ctx.root.innerHTML = `
            <div class="g-center">
                <div class="hk-head"><span class="hk-mode"></span><span class="hk-count"></span></div>
                <div class="hk-show"><i></i></div>
                <div class="hk-grid" style="grid-template-columns: repeat(${o.cols}, 1fr)"></div>
            </div>`;
        const grid = ctx.root.querySelector('.hk-grid');
        const mode = ctx.root.querySelector('.hk-mode');
        const count = ctx.root.querySelector('.hk-count');
        const showBar = ctx.root.querySelector('.hk-show i');

        let round = 1, mistakes = 0, expected = 1, total = 0, input = false, timers = [];
        const later = (fn, ms) => timers.push(setTimeout(fn, ms));

        const stats = () => ctx.stats(ctx.round(round) + (o.mistakes > 0 ? ctx.pill(`${ctx.L('mg_mistakes')} ${mistakes}/${o.mistakes}`, mistakes ? 'warn' : 'mute') : ''));

        function build() {
            total = Math.min(o.cols * o.rows, o.numbers + round - 1);
            expected = 1;
            const cells = o.cols * o.rows;
            const slots = LAFLGames.shuffle([...Array(cells).keys()]).slice(0, total);
            grid.innerHTML = '';
            for (let i = 0; i < cells; i++) {
                const n = slots.indexOf(i) + 1;
                const b = document.createElement('button');
                b.className = 'hk-cell' + (n ? ' num shown' : '');
                b.dataset.n = n || 0;
                b.textContent = n ? n : '';
                b.addEventListener('click', () => click(b));
                grid.appendChild(b);
            }
            input = false;
            ctx.pauseTimer(true);
            mode.textContent = ctx.L('hack_memorize');
            mode.className = 'hk-mode';
            count.textContent = '';
            showBar.style.transition = 'none';
            showBar.style.transform = 'scaleX(1)';
            void showBar.offsetWidth;
            showBar.style.transition = `transform ${o.show}s linear`;
            showBar.style.transform = 'scaleX(0)';
            stats();
            later(() => {
                grid.querySelectorAll('.num').forEach(c => { c.classList.remove('shown'); c.textContent = ''; });
                mode.textContent = ctx.L('hack_input');
                mode.className = 'hk-mode input';
                count.textContent = `0/${total}`;
                input = true;
                ctx.pauseTimer(false);
            }, o.show * 1000);
        }

        function click(b) {
            if (!input || b.classList.contains('ok')) return;
            const n = Number(b.dataset.n);
            if (n === expected) {
                b.classList.add('ok');
                b.textContent = n;
                ctx.sound(500 + expected * 60, 50);
                count.textContent = `${expected}/${total}`;
                expected++;
                if (expected > total) {
                    input = false;
                    if (round >= o.rounds) return ctx.win();
                    round++;
                    later(build, 600);
                }
            } else {
                b.classList.add('bad');
                if (n) b.textContent = n;
                ctx.sound(180, 120, 'square', 0.03);
                ctx.shake();
                mistakes++;
                stats();
                later(() => { b.classList.remove('bad'); if (!b.classList.contains('ok')) b.textContent = ''; }, 500);
                if (mistakes > o.mistakes) { input = false; ctx.fail(); }
            }
        }

        later(build, 300);
        return () => timers.forEach(clearTimeout);
    },
});
