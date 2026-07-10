/**
 * Audio Player
 * -----------------------------------------------------------
 * Site-wide soundtrack. Builds a persistent <audio> + floating
 * toggle button, and keeps playback continuous across page
 * navigations (index → fr → collection pages) using
 * localStorage to remember play state, position and volume.
 *
 * To change the track, replace /audio/theme.mp3 at the project
 * root — no other changes needed.
 *
 * Labels are picked up from the page's [lang] attribute so the
 * FR pages show French text automatically.
 */
(function () {
  var STORAGE_KEY = 'zuma-audio-state';

  // Resolve the audio file relative to THIS script's own URL,
  // so the path works correctly no matter how deep the current
  // page is nested (root, /collections/x/, /templates/x/...).
  var scriptEl = document.currentScript;
  var baseURL = scriptEl.src.replace(/scripts\/core\/audio-player\.js.*$/, '');
  var AUDIO_SRC = baseURL + 'audio/theme.mp3';

  var isFR = (document.documentElement.lang || '').toLowerCase().indexOf('fr') === 0;
  var LABEL_PLAY = isFR ? 'Son' : 'Sound';
  var LABEL_PAUSE = isFR ? 'Pause' : 'Pause';

  function readState() {
    try {
      return JSON.parse(localStorage.getItem(STORAGE_KEY)) || {};
    } catch (e) {
      return {};
    }
  }

  function writeState(partial) {
    var current = readState();
    var next = Object.assign(current, partial);
    try {
      localStorage.setItem(STORAGE_KEY, JSON.stringify(next));
    } catch (e) {
      /* storage unavailable — playback just won't persist */
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

    var toggle = document.createElement('button');
    toggle.id = 'zuma-audio-toggle';
    toggle.type = 'button';
    toggle.setAttribute('aria-label', isFR ? 'Activer / couper le son' : 'Toggle soundtrack');
    toggle.innerHTML =
      '<span class="zuma-audio-bars"><span></span><span></span><span></span></span>' +
      '<span class="zuma-audio-label">' + LABEL_PLAY + '</span>';
    document.body.appendChild(toggle);

    var label = toggle.querySelector('.zuma-audio-label');

    function setUIPlaying(playing) {
      toggle.classList.toggle('is-playing', playing);
      label.textContent = playing ? LABEL_PAUSE : LABEL_PLAY;
    }

    function attemptPlay() {
      var p = audio.play();
      if (p && typeof p.then === 'function') {
        p.then(function () {
          setUIPlaying(true);
          writeState({ playing: true });
        }).catch(function () {
          // Autoplay blocked by the browser — stay paused until
          // the visitor clicks the toggle themselves.
          setUIPlaying(false);
          writeState({ playing: false });
        });
      }
    }

    // Resume automatically only if the visitor had already
    // started the soundtrack earlier in this session.
    if (state.playing) {
      attemptPlay();
    } else {
      setUIPlaying(false);
    }

    toggle.addEventListener('click', function () {
      if (audio.paused) {
        attemptPlay();
      } else {
        audio.pause();
        setUIPlaying(false);
        writeState({ playing: false, time: audio.currentTime });
      }
    });

    // Keep the saved position fresh so navigating to the next
    // page resumes right where this one left off.
    audio.addEventListener('timeupdate', function () {
      writeState({ time: audio.currentTime });
    });

    window.addEventListener('beforeunload', function () {
      writeState({ time: audio.currentTime, playing: !audio.paused });
    });

    // Pages regain focus (e.g. back/forward cache) — make sure
    // the button reflects reality.
    document.addEventListener('visibilitychange', function () {
      if (!document.hidden) {
        setUIPlaying(!audio.paused);
      }
    });
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }
})();
