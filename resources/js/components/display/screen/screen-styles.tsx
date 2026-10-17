/**
 * The few keyframes the screen needs (the app stylesheet is shared, so they
 * live here). Every animation stops for visitors who ask for less motion.
 */
const CSS = `
@keyframes d-fade-up { from { opacity: 0; transform: translateY(1.2cqmin); } to { opacity: 1; transform: none; } }
@keyframes d-fade { from { opacity: 0; } to { opacity: 1; } }
@keyframes d-ripple { 0% { transform: scale(.55); opacity: .55; } 100% { transform: scale(1.65); opacity: 0; } }
@keyframes d-breathe { 0%, 100% { opacity: .55; } 50% { opacity: 1; } }
@keyframes d-twinkle { 0%, 100% { opacity: .25; } 50% { opacity: 1; } }
@keyframes d-glow { 0%, 100% { box-shadow: 0 0 0 0 color-mix(in oklab, var(--d-accent) 0%, transparent); } 50% { box-shadow: 0 0 3cqmin .3cqmin color-mix(in oklab, var(--d-accent) 45%, transparent); } }
@keyframes d-drift { 0% { transform: translate(0, 0); } 50% { transform: translate(1.5cqmin, -1cqmin); } 100% { transform: translate(0, 0); } }
.d-fade-up { animation: d-fade-up .9s cubic-bezier(.2,.7,.2,1) both; }
.d-fade { animation: d-fade 1.2s ease both; }
.d-ripple { animation: d-ripple 4.5s cubic-bezier(.2,.6,.3,1) infinite; }
.d-breathe { animation: d-breathe 3.2s ease-in-out infinite; }
.d-twinkle { animation: d-twinkle 4s ease-in-out infinite; }
.d-glow { animation: d-glow 2.6s ease-in-out infinite; }
.d-drift { animation: d-drift 90s ease-in-out infinite; }
@media (prefers-reduced-motion: reduce) {
  .d-fade-up, .d-fade, .d-ripple, .d-breathe, .d-twinkle, .d-glow, .d-drift { animation: none !important; }
  .d-stage, .d-stage * { transition: none !important; }
}
`;

export function ScreenStyles() {
    return (
        <style href="salat-display-keyframes" precedence="default">
            {CSS}
        </style>
    );
}
