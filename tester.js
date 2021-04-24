		var exclude = ["mjallday"]


		function filter(array) {
			return array.filter(function(value, index, arr){ 
				return !exclude.includes(value);
			});
		}

console.log(filter(["alexellis", "mjallday"]))
