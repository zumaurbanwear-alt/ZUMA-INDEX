/**
 * Scroll reveal
 * -----------------------------------------------------------
 * Watches every `.reveal` element (see styles/animations/reveal.css)
 * and adds `.visible` the moment it enters the viewport, which
 * triggers the fade/translate CSS transition.
 */
const revealObserver = new IntersectionObserver(
  (entries) => {
    entries.forEach((entry) => {
      if (entry.isIntersecting) {
        entry.target.classList.add('visible');
      }
    });
  },
  { threshold: 0.05, rootMargin: '0px 0px -20px 0px' }
);

document.querySelectorAll('.reveal').forEach((el) => revealObserver.observe(el));
