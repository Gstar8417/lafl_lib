// Thermite: tiles light up for a short time, then click all of them (any order).
// opts: rounds, size (grid size), tiles (first round, +1 per round), show (seconds), mistakes
LAFLGames.register('thermite', {
    icon: '🔥',
    width: 480,
    presets: {
        easy:   { rounds: 2, size: 5, tiles: 7,  show: 3.0, mistakes: 2, time: 45 },
        medium: { rounds: 3, size: 6, tiles: 10, show: 2.8, mistakes: 1, time: 50 },
        hard:   { rounds: 3, size: 7, tiles: 13, show: 2.5, mistakes: 0, time: 50 },
    },
    start(ctx) {
        const o = ctx.opts;
        ctx.root.innerHTML = `
            <div class="g-center">
                <div class="hk-head"><span class="hk-mode"></span><span class="hk-count"></span></div>
                <div class="hk-show"><i></i></div>
                <div class="th-grid" style="grid-template-columns: repeat(${o.size}, 1fr)"></div>
            </div>`;
        const grid = ctx.root.querySelector('.th-grid');
        const mode = ctx.root.querySelector('.hk-mode');
        const count = ctx.root.querySelector('.hk-count');
        const showBar = ctx.root.querySelector('.hk-show i');

        let round = 1, mistakes = 0, found = 0, total = 0, input = false, timers = [];
        const later = (fn, ms) => timers.push(setTimeout(fn, ms));
        const stats = () => ctx.stats(ctx.round(round) + ctx.pill(`${ctx.L('mg_mistakes')} ${mistakes}/${o.mistakes}`, mistakes ? 'warn' : 'mute'));

        function build() {
            const cells = o.size * o.size;
            total = Math.min(cells - 1, o.tiles + round - 1);
            found = 0;
            const lit = new Set(LAFLGames.shuffle([...Array(cells).keys()]).slice(0, total));
            grid.innerHTML = '';
            for (let i = 0; i < cells; i++) {
                const b = document.createElement('button');
                b.className = 'th-cell' + (lit.has(i) ? ' target lit' : '');
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
                grid.querySelectorAll('.lit').forEach(c => c.classList.remove('lit'));
                mode.textContent = ctx.L('hack_input');
                mode.className = 'hk-mode input';
                count.textContent = `0/${total}`;
                input = true;
                ctx.pauseTimer(false);
            }, o.show * 1000);
        }

        function click(b) {
            if (!input || b.classList.contains('ok') || b.classList.contains('bad')) return;
            if (b.classList.contains('target')) {
                b.classList.add('ok');
                found++;
                count.textContent = `${found}/${total}`;
                ctx.sound(420 + found * 35, 45, 'triangle');
                if (found >= total) {
                    input = false;
                    if (round >= o.rounds) return ctx.win();
                    round++;
                    later(build, 650);
                }
            } else {
                b.classList.add('bad');
                ctx.sound(160, 130, 'square', 0.03);
                ctx.shake();
                mistakes++;
                stats();
                if (mistakes > o.mistakes) {
                    input = false;
                    grid.querySelectorAll('.target:not(.ok)').forEach(c => c.classList.add('missed'));
                    ctx.fail();
                }
            }
        }

        later(build, 300);
        return () => timers.forEach(clearTimeout);
    },
});
