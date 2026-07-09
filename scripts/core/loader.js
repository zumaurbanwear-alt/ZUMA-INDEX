/**
 * Loader
 * -----------------------------------------------------------
 * The <body> starts with `visibility: hidden` (inline in <head>)
 * to prevent a flash of unstyled content while fonts/CSS settle.
 * This module reveals the body immediately, shows the splash,
 * then fades the splash out shortly after the window's `load`
 * event (just enough to mask the initial paint).
 */
document.body.style.visibility = 'visible';
document.getElementById('loader').style.display = 'block';

window.addEventListener('load', () => {
  setTimeout(() => {
    document.getElementById('loader').classList.add('hidden');
  }, 50);
});
