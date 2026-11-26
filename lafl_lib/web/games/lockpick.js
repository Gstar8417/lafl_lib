// Lockpick: move the pick (mouse / A D), hold Space to turn the cylinder.
// The closer the pick is to the hidden spot, the further the cylinder turns.
// opts: rounds (pins), tolerance (deg), picks, damage (per second while stuck)
LAFLGames.register('lockpick', {
    icon: '🔓',
    width: 460,
    presets: {
        easy:   { rounds: 3, tolerance: 14, picks: 3, damage: 0.55 },
        medium: { rounds: 4, tolerance: 9,  picks: 2, damage: 0.8 },
        hard:   { rounds: 5, tolerance: 5,  picks: 1, damage: 1.1 },
    },
    start(ctx) {
        const o = ctx.opts;
        let pins = '';
        for (let i = 0; i < o.rounds; i++) {
            const a = (-60 + 120 * (o.rounds === 1 ? 0.5 : i / (o.rounds - 1))) * Math.PI / 180;
            pins += `<circle class="lp-pin" cx="${130 + Math.sin(a) * 114}" cy="${130 - Math.cos(a) * 114}" r="6"/>`;
        }
        ctx.root.innerHTML = `
            <div class="g-center">
                <svg class="lp" viewBox="0 0 260 260" width="280" height="280">
                    ${pins}
                    <circle cx="130" cy="130" r="100" class="lp-body"/>
                    <g class="lp-cyl">
                        <circle cx="130" cy="130" r="64" class="lp-cyl-c"/>
                        <rect x="127" y="70" width="6" height="14" rx="2" class="lp-notch"/>
                        <circle cx="130" cy="122" r="11" class="lp-hole"/>
                        <rect x="125" y="122" width="10" height="30" rx="3" class="lp-hole"/>
                    </g>
                    <rect x="127" y="150" width="6" height="95" rx="2" class="lp-wrench"/>
                    <g class="lp-pick"><rect x="128.5" y="18" width="3" height="104" rx="1.5"/><rect x="125" y="6" width="10" height="26" rx="4" class="lp-handle"/></g>
                </svg>
                <div class="g-meter" style="width:240px">
                    <div class="label">${ctx.esc(ctx.L('lockpick_picks'))} <b class="lp-picks"></b></div>
                    <div class="g-meter-bar"><i class="lp-health" style="width:100%"></i></div>
                </div>
            </div>`;

        const svg = ctx.root.querySelector('svg');
        const cyl = ctx.root.querySelector('.lp-cyl');
        const pick = ctx.root.querySelector('.lp-pick');
        const healthEl = ctx.root.querySelector('.lp-health');
        const picksEl = ctx.root.querySelector('.lp-picks');
        const pinEls = ctx.root.querySelectorAll('.lp-pin');

        let round = 1, picks = o.picks, health = 1, theta = 90, turn = 0, sweet = 0, holding = false, keys = {}, locked = false, tickT = 0;

        const stats = () => {
            ctx.stats(ctx.round(round));
            picksEl.textContent = `${picks}/${o.picks}`;
        };
        const newPin = () => { sweet = LAFLGames.rand(15, 165); turn = 0; };

        const onMove = e => {
            const r = svg.getBoundingClientRect();
            const dx = e.clientX - (r.left + r.width / 2);
            const dy = (r.top + r.height / 2) - e.clientY;
            let a = Math.atan2(Math.max(dy, -20), dx) * 180 / Math.PI;
            theta = Math.max(0, Math.min(180, 180 - a));
        };
        const down = e => { const k = LAFLGames.key(e); if (k === 'escape') return; keys[k] = true; if (k === ' ' || k === 'e' || k === 'w') holding = true; };
        const up = e => { const k = LAFLGames.key(e); keys[k] = false; if (k === ' ' || k === 'e' || k === 'w') holding = false; };
        const mDown = () => { holding = true; };
        const mUp = () => { holding = false; };
        window.addEventListener('mousemove', onMove);
        window.addEventListener('keydown', down);
        window.addEventListener('keyup', up);
        ctx.root.addEventListener('mousedown', mDown);
        window.addEventListener('mouseup', mUp);

        newPin();
        stats();

        ctx.loop(dt => {
            if (locked) return;
            if (keys.a || keys.arrowleft) theta = Math.max(0, theta - 80 * dt);
            if (keys.d || keys.arrowright) theta = Math.min(180, theta + 80 * dt);

            const dist = Math.abs(theta - sweet);
            const maxTurn = dist <= o.tolerance ? 90 : Math.max(0, 90 * (1 - (dist - o.tolerance) / 45));
            let jitter = 0;

            if (holding) {
                turn = Math.min(maxTurn, turn + 130 * dt);
                if (maxTurn < 90 && turn >= maxTurn - 0.5) {
                    // stuck: pick takes damage
                    health -= o.damage * dt;
                    jitter = LAFLGames.rand(-1.6, 1.6);
                    tickT -= dt;
                    if (tickT <= 0) { ctx.sound(140, 25, 'square', 0.015); tickT = 0.09; }
                    if (health <= 0) {
                        picks--;
                        health = 1;
                        turn = 0;
                        holding = false;
                        ctx.sound(300, 160, 'sawtooth', 0.04);
                        ctx.shake();
                        stats();
                        if (picks <= 0) { locked = true; return ctx.fail(ctx.L('lockpick_broke')); }
                    }
                }
                if (turn >= 89.5) {
                    pinEls[round - 1] && pinEls[round - 1].classList.add('open');
                    ctx.sound(760, 60); setTimeout(() => ctx.sound(1020, 80), 70);
                    if (round >= o.rounds) { locked = true; cyl.setAttribute('transform', 'rotate(90 130 130)'); return ctx.win(); }
                    round++;
                    holding = false;
                    newPin();
                    stats();
                }
            } else {
                turn = Math.max(0, turn - 220 * dt);
            }

            cyl.setAttribute('transform', `rotate(${turn + jitter} 130 130)`);
            pick.setAttribute('transform', `rotate(${theta - 90 + turn * 0.25 + jitter} 130 130)`);
            healthEl.style.width = (health * 100) + '%';
            healthEl.style.background = health < 0.35 ? 'var(--red)' : '';
        });

        return () => {
            window.removeEventListener('mousemove', onMove);
            window.removeEventListener('keydown', down);
            window.removeEventListener('keyup', up);
            window.removeEventListener('mouseup', mUp);
        };
    },
});
