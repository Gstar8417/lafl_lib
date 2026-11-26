// Wires: follow the tangled wires from ⚡ back to the start and cut the right one.
// Wires can only be cut at the cut marks on the LEFT, so the wire has to be traced.
// opts: rounds (panels), wires, colors (number of different colors, fewer = harder)
LAFLGames.register('wires', {
    icon: '✂️',
    width: 560,
    presets: {
        easy:   { rounds: 2, wires: 4, colors: 4, time: 30 },
        medium: { rounds: 3, wires: 6, colors: 3, time: 40 },
        hard:   { rounds: 3, wires: 7, colors: 2, time: 40 },
    },
    start(ctx) {
        const o = ctx.opts;
        const PALETTE = ['#ef5b4c', '#5aa9e6', '#f0a63a', '#5fd38d', '#b38cf0', '#e9ede4'];
        const W = 500, H = 290, X0 = 52, X1 = W - 52, CUT = X0 + 30;
        const R = LAFLGames.rand;

        ctx.root.innerHTML = `<svg class="wr" viewBox="0 0 ${W} ${H}" width="${W}" height="${H}"></svg>`;
        const svg = ctx.root.querySelector('svg');
        let round = 1, busy = false, timers = [];
        const later = (fn, ms) => timers.push(setTimeout(fn, ms));
        const stats = () => ctx.stats(ctx.round(round));

        /** S-shaped path: straight start (cut zone) -> two random bends -> end */
        function wirePath(y0, y1) {
            const m1x = R(150, 215), m1y = R(15, H - 15);
            const m2x = R(285, 350), m2y = R(15, H - 15);
            return `M ${X0} ${y0} L ${CUT + 14} ${y0} ` +
                   `C ${CUT + 60} ${y0}, ${m1x - 40} ${m1y}, ${m1x} ${m1y} ` +
                   `S ${m2x - 40} ${m2y}, ${m2x} ${m2y} ` +
                   `S ${X1 - 50} ${y1}, ${X1} ${y1}`;
        }

        function build() {
            const n = Math.max(2, Math.min(8, o.wires));
            const ys = [...Array(n).keys()].map(i => 22 + i * (H - 44) / (n - 1));
            let perm;
            do { perm = LAFLGames.shuffle([...Array(n).keys()]); } while (perm.some((p, i) => p === i) && n > 2 && Math.random() < 0.85);
            const target = LAFLGames.randInt(0, n - 1);   // right terminal with ⚡
            const colors = LAFLGames.shuffle(PALETTE.slice(0, Math.max(1, Math.min(o.colors, PALETTE.length))));

            let lines = '', cuts = '';
            for (let i = 0; i < n; i++) {
                const color = colors[i % colors.length];
                const d = wirePath(ys[i], ys[perm[i]]);
                lines += `<g class="wr-wire" data-i="${i}"><path d="${d}" class="wr-shadow"/><path d="${d}" class="wr-line" stroke="${color}"/></g>`;
                cuts += `<g class="wr-cut" data-i="${i}">
                            <rect x="${CUT - 11}" y="${ys[i] - 11}" width="22" height="22" rx="6"/>
                            <text x="${CUT}" y="${ys[i] + 4.5}">✂</text>
                         </g>
                         <circle cx="${X0}" cy="${ys[i]}" r="7" class="wr-term" fill="${color}"/>`;
            }
            let ends = '';
            ys.forEach((y, j) => {
                ends += `<circle cx="${X1}" cy="${y}" r="7" class="wr-term end"/>
                         <text x="${X1 + 21}" y="${y + 5}" class="wr-label${j === target ? ' target' : ''}">${j === target ? '⚡' : '·'}</text>`;
            });

            svg.innerHTML = `<rect x="${X0 - 34}" y="6" width="26" height="${H - 12}" rx="6" class="wr-block"/>
                             <rect x="${X1 + 8}" y="6" width="26" height="${H - 12}" rx="6" class="wr-block"/>
                             ${lines}${cuts}${ends}`;
            busy = false;
            stats();

            svg.querySelectorAll('.wr-cut').forEach(g => {
                g.addEventListener('click', () => {
                    if (busy) return;
                    busy = true;
                    const i = Number(g.dataset.i);
                    g.classList.add('done');
                    svg.querySelector(`.wr-wire[data-i="${i}"]`).classList.add('cut');
                    ctx.sound(1200, 30, 'square', 0.03);
                    if (perm[i] === target) {
                        later(() => {
                            if (round >= o.rounds) return ctx.win();
                            round++;
                            ctx.sound(760, 70);
                            build();
                        }, 450);
                    } else {
                        svg.querySelectorAll('.wr-wire').forEach(w => { if (perm[Number(w.dataset.i)] === target) w.classList.add('was'); });
                        ctx.fail();
                    }
                });
            });
        }

        build();
        return () => timers.forEach(clearTimeout);
    },
});
