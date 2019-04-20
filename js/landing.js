function toggleUsers() {
	var toggler = document.getElementById('show-more-users');
	var usersWrapper = document.querySelector('.users .users-wrapper');

	toggler.addEventListener('click', function() {
		if (usersWrapper.classList.contains('show-less')) {
			toggler.innerText = 'Less';
		} else {
			toggler.innerText = 'View more';
		}

		usersWrapper.classList.toggle('show-less');
	})
}

/*------------Init scripts on pageload--------------*/
/*--------------------------------------------------*/
document.addEventListener('DOMContentLoaded', function() {
    toggleUsers()
})
