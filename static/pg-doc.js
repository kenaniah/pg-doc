$(document).ready(() => {

	// Toggles submenues in navigation
	$(document).on("click", ".js-submenu", (event) => {
		$(event.currentTarget).find("I.caret").transition('toggle')
		$(event.currentTarget).next("DIV.menu").transition('toggle')
	})

	// Handles code highlighting
	$('PRE').each((i, block) => {
		hljs.highlightBlock(block)
	})

});
