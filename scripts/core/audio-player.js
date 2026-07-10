 /**
 * Audio Player
 * -----------------------------------------------------------
 * Site-wide soundtrack, no visible UI. Tries to autoplay on
 * load; if the browser blocks it (standard policy — sound
 * can't start without a prior user gesture), it starts
 * silently on the visitor's very first click/tap/keypress
 * anywhere on the page. Position + play state persist across
 * page navigations via localStorage.
 *
 * To change the track, replace /audio/theme.mp3 at the project
 * root — no other changes needed.
 */
(function () {
  var STORAGE_KEY = 'zuma-audio-state';
  var scriptEl = document.currentScript;
  var baseURL = scriptEl.src.replace(/scripts\/core\/audio-player\.js.*$/, '');
  var AUDIO_SRC = baseURL + 'audio/theme.mp3';
  function readState() {
    try {
      return JSON.parse(localStorage.getItem(STORAGE_KEY)) || {};
    } catch (e) {
return {}; }
}
  function writeState(partial) {
    var current = readState();
    var next = Object.assign(current, partial);
    try {
      localStorage.setItem(STORAGE_KEY, JSON.stringify(next));
    } catch (e) {
      /* storage unavailable */
    }
}
  function init() {
    var state = readState();
    var audio = new Audio(AUDIO_SRC);
    audio.loop = true;
    audio.volume = typeof state.volume === 'number' ? state.volume : 0.5;
     audio.preload = 'auto';
    if (typeof state.time === 'number') {
      audio.currentTime = state.time;
    }
    function markPlaying() {
      writeState({ playing: true });
}
    function tryPlay() {
      var p = audio.play();
      if (p && typeof p.then === 'function') {
        p.then(markPlaying).catch(armFallback);
      }
}
    function armFallback() {
      var events = ['click', 'touchstart', 'keydown', 'scroll'];
      function start() {
        events.forEach(function (ev) { document.removeEventListener(ev, start); });
        audio.play().then(markPlaying).catch(function () {});
      }
      events.forEach(function (ev) {
        document.addEventListener(ev, start, { once: true, passive: true });
}); }
    if (state.playing !== false) {
      tryPlay();
}
    audio.addEventListener('timeupdate', function () {
      writeState({ time: audio.currentTime });
});
    window.addEventListener('beforeunload', function () {
      writeState({ time: audio.currentTime, playing: !audio.paused });
}); }
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
} })();

 
