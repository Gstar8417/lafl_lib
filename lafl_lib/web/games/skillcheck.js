// Skill check: press the shown key while the pointer is inside the zone.
// opts: rounds, zone (degrees), speed (deg/s), keys (['e'] or ['w','a','s','d']), mistakes
LAFLGames.register('skillcheck', {
    icon: '🎯',
    width: 420,
    presets: {
        easy:   { rounds: 3, zone: 55, speed: 210, mistakes: 1, keys: ['e'] },
        medium: { rounds: 4, zone: 40, speed: 290, mistakes: 0, keys: ['e'] },
        hard:   { rounds: 5, zone: 28, speed: 380, mistakes: 0, keys: ['w', 'a', 's', 'd'] },
    },
    start(ctx) {
        const o = ctx.opts;
        const R = 88, C = 2 * Math.PI * R;
        ctx.root.innerHTML = `
            <div class="sc-wrap">
                <svg class="sc" viewBox="0 0 220 220" width="230" height="230">
                    <circle cx="110" cy="110" r="${R}" class="sc-track"/>
                    <circle cx="110" cy="110" r="${R}" class="sc-zone" transform="rotate(-90 110 110)"/>
                    <g class="sc-needle"><rect x="107" y="10" width="6" height="30" rx="3"/></g>
                </svg>
                <div class="sc-key kbd"></div>
            </div>`;
        const zoneEl = ctx.root.querySelector('.sc-zone');
        const needle = ctx.root.querySelector('.sc-needle');
        const keyEl = ctx.root.querySelector('.sc-key');

        let round = 1, mistakes = 0, angle = 0, zoneStart = 0, key = 'e', speed = o.speed, active = false;

        const stats = () => ctx.stats(ctx.round(round) + (o.mistakes > 0 ? ctx.pill(`${ctx.L('mg_mistakes')} ${mistakes}/${o.mistakes}`, mistakes ? 'warn' : 'mute') : ''));

        function next() {
            angle = 0;
            zoneStart = LAFLGames.rand(110, 330 - o.zone);
            key = o.keys[Math.floor(Math.random() * o.keys.length)].toLowerCase();
            speed = o.speed * LAFLGames.rand(0.9, 1.15);
            zoneEl.style.strokeDasharray = `${C * o.zone / 360} ${C}`;
            zoneEl.style.strokeDashoffset = `${-C * zoneStart / 360}`;
            zoneEl.classList.remove('hit', 'miss');
            keyEl.textContent = key.toUpperCase();
            active = true;
            stats();
        }

        function miss() {
            active = false;
            zoneEl.classList.add('miss');
            mistakes++;
            ctx.sound(200, 140, 'square', 0.03);
            ctx.shake();
            if (mistakes > o.mistakes) return ctx.fail();
            setTimeout(next, 450);
        }

        function hit() {
            active = false;
            zoneEl.classList.add('hit');
            ctx.sound(880, 70);
            if (round >= o.rounds) return ctx.win();
            round++;
            setTimeout(next, 350);
        }

        const onKey = e => {
            const k = LAFLGames.key(e);
            if (!active || e.repeat || k === 'escape' || k === 'shift') return;
            if (k !== key) return miss();
            if (angle >= zoneStart && angle <= zoneStart + o.zone) hit(); else miss();
        };
        window.addEventListener('keydown', onKey);

        // single key (default E): a left click counts as that key too
        const onClick = e => {
            if (e.button !== 0 || o.keys.length !== 1 || !active) return;
            if (angle >= zoneStart && angle <= zoneStart + o.zone) hit(); else miss();
        };
        ctx.root.addEventListener('mousedown', onClick);

        ctx.loop(dt => {
            if (!active) return;
            angle += speed * dt;
            needle.setAttribute('transform', `rotate(${angle} 110 110)`);
            if (angle > zoneStart + o.zone + 8) miss();
        });

        setTimeout(next, 400);
        stats();
        return () => { window.removeEventListener('keydown', onKey); ctx.root.removeEventListener('mousedown', onClick); };
    },
});
