// Drill: hold Space / mouse for pressure, keep it in the green zone.
// Too much pressure heats the drill, releasing cools it down. Overheating = fail.
// opts: rounds (layers), zone (width in %), heat (heat per second in the zone), speed (% per second)
LAFLGames.register('drill', {
    icon: '🛠️',
    width: 540,
    presets: {
        easy:   { rounds: 3, zone: 30, heat: 6,  speed: 18, time: 80 },
        medium: { rounds: 4, zone: 22, heat: 8,  speed: 16, time: 80 },
        hard:   { rounds: 5, zone: 15, heat: 10, speed: 14, time: 80 },
    },
    start(ctx) {
        const o = ctx.opts;
        let layers = '';
        for (let i = 0; i < o.rounds; i++) layers += `<div class="dr-layer"><i></i></div>`;
        ctx.root.innerHTML = `
            <div class="g-center dr">
                <div class="dr-plate">
                    <div class="dr-layers">${layers}</div>
                    <div class="dr-bit"><div class="dr-sparks"></div></div>
                </div>
                <div class="g-meter">
                    <div class="label">${ctx.esc(ctx.L('drill_pressure'))} <b class="dr-pv">0%</b></div>
                    <div class="g-meter-bar"><div class="zone"></div><div class="needle"></div></div>
                </div>
                <div class="g-meter">
                    <div class="label">${ctx.esc(ctx.L('drill_heat'))} <b class="dr-hv">0%</b></div>
                    <div class="g-meter-bar dr-heat"><i></i></div>
                </div>
            </div>`;

        const zoneEl = ctx.root.querySelector('.zone');
        const needle = ctx.root.querySelector('.needle');
        const heatEl = ctx.root.querySelector('.dr-heat i');
        const pv = ctx.root.querySelector('.dr-pv');
        const hv = ctx.root.querySelector('.dr-hv');
        const bit = ctx.root.querySelector('.dr-bit');
        const plate = ctx.root.querySelector('.dr-plate');
        const layerEls = ctx.root.querySelectorAll('.dr-layer');

        let round = 1, pressure = 0, heat = 0, progress = 0, zoneStart = 0, holding = false, done = false, hum = 0;

        const newZone = () => {
            zoneStart = LAFLGames.rand(25, 92 - o.zone);
            zoneEl.style.left = zoneStart + '%';
            zoneEl.style.width = o.zone + '%';
        };
        const stats = () => ctx.stats(ctx.round(round));

        const isHold = k => k === ' ' || k === 'w' || k === 'e';
        const down = e => { if (isHold(LAFLGames.key(e))) holding = true; };
        const up = e => { if (isHold(LAFLGames.key(e))) holding = false; };
        const mDown = () => { holding = true; };
        const mUp = () => { holding = false; };
        window.addEventListener('keydown', down);
        window.addEventListener('keyup', up);
        ctx.root.addEventListener('mousedown', mDown);
        window.addEventListener('mouseup', mUp);

        newZone();
        stats();

        ctx.loop(dt => {
            if (done) return;
            pressure = Math.max(0, Math.min(100, pressure + (holding ? 75 : -95) * dt));
            const inZone = pressure >= zoneStart && pressure <= zoneStart + o.zone;
            const over = pressure > zoneStart + o.zone;

            if (inZone) { progress += o.speed * dt; heat += o.heat * dt; }
            else if (over) { progress += o.speed * 0.35 * dt; heat += 42 * dt; }
            else heat -= (pressure < 5 ? 30 : 20) * dt;
            heat = Math.max(0, heat);

            plate.classList.toggle('drilling', inZone || over);
            plate.classList.toggle('hot', heat > 70);
            hum -= dt;
            if ((inZone || over) && hum <= 0) { ctx.sound(over ? 120 : 90, 60, 'sawtooth', 0.012); hum = 0.12; }

            if (heat >= 100) {
                done = true;
                heatEl.style.width = '100%';
                return ctx.fail(ctx.L('drill_broke'));
            }

            if (progress >= 100) {
                layerEls[round - 1].classList.add('done');
                ctx.sound(820, 70);
                progress = 0;
                if (round >= o.rounds) { done = true; bit.style.left = '100%'; return ctx.win(); }
                round++;
                newZone();
                stats();
            }

            const layerFill = layerEls[round - 1] && layerEls[round - 1].querySelector('i');
            if (layerFill) layerFill.style.width = progress + '%';
            bit.style.left = (((round - 1) + progress / 100) / o.rounds * 100) + '%';
            needle.style.left = pressure + '%';
            needle.classList.toggle('bad', over);
            heatEl.style.width = heat + '%';
            heatEl.style.background = heat > 75 ? 'var(--red)' : heat > 45 ? 'var(--amber)' : 'var(--green)';
            pv.textContent = Math.round(pressure) + '%';
            hv.textContent = Math.round(heat) + '%';
        });

        return () => {
            window.removeEventListener('keydown', down);
            window.removeEventListener('keyup', up);
            window.removeEventListener('mouseup', mUp);
        };
    },
});
