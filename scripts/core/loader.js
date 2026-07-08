/**
 * Loader
 * -----------------------------------------------------------
 * The <body> starts with `visibility: hidden` (inline in <head>)
 * to prevent a flash of unstyled content while fonts/CSS settle.
 * This module reveals the body immediately, shows the splash,
 * then hides the splash 2.4s after the window's `load` event.
 */
document.body.style.visibility = 'visible';
document.getElementById('loader').style.display = 'flex';

window.addEventListener('load', () => {
  setTimeout(() => {
    document.getElementById('loader').classList.add('hidden');
  }, 2400);
});
