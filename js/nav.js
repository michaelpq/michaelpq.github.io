// Progressive enhancement for the top navigation menu on small screens.
//
// The menu is fully visible and usable without this script (see the
// mobile rules in css/main.css). This file only adds the collapse/expand
// behaviour behind the hamburger button, since it's the only thing that
// requires script: it also keeps the button's aria-expanded state in
// sync for assistive technology.
(function () {
	var toggle = document.getElementById('menu-toggle');
	var nav = document.getElementById('topmenu');
	var list = document.getElementById('topmenu-list');

	if (!toggle || !nav || !list) {
		return;
	}

	// Only start hiding the menu once we know we can also open it back
	// up. Without this class the CSS keeps the full list visible.
	nav.classList.add('js-collapsible');
	toggle.setAttribute('aria-expanded', 'false');

	toggle.addEventListener('click', function () {
		var isOpen = nav.classList.toggle('nav-open');
		toggle.setAttribute('aria-expanded', isOpen ? 'true' : 'false');
	});

	// Close the menu again once a link inside it is used, so it doesn't
	// stay open when navigating to the next page on mobile.
	list.addEventListener('click', function (event) {
		if (event.target.closest('a')) {
			nav.classList.remove('nav-open');
			toggle.setAttribute('aria-expanded', 'false');
		}
	});
})();
