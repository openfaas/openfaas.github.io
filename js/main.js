(function () {
	var header = document.getElementById("mainHeader");

	function changeHeader() {
		var scrollTop = document.documentElement.scrollTop || document.body.scrollTop;
		header.classList.toggle("header-background", scrollTop >= 50 || document.body.classList.contains("nav-open"));
	}

	var stars = 0;

	const getGithubStars = async() => {
		const response = await fetch('https://api.github.com/repos/openfaas/faas');
		  const json = await response.json();		  
		  stars = Math.floor(json.stargazers_count/100)*100;
		  stars = stars.toString().replace(/\B(?=(\d{3})+(?!\d))/g, ",");
		  document.getElementById("github-starcount").innerHTML = stars;
	}

	getGithubStars();

	var didScroll = false;

	$(window).scroll(function () {
		didScroll = true;
	});

	setInterval(function() {
		if (didScroll) {
			didScroll = false;
			changeHeader();
		}
	}, 100);

	changeHeader();

	document.getElementById("open-nav").addEventListener("click", function (event) {
		event.preventDefault();
		document.body.classList.toggle("nav-open");
		changeHeader();
	});
})();
