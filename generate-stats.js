const https = require('https');
const fs = require('fs');
const maxRetry = 3;
let retries = 0;

function sortContribs(data) {
	let groupedUsers = [];
	const rows = [12, 13, 14, 14]; // users/row
	const sortedEntries = Object.entries(data.byLogin).sort((a, b) => b[1] - a[1]);

	data.byLogin = sortedEntries.reduce((a, b) => { a[b[0]] = b[1]; return a; }, {});

	rows.forEach(r => {
		groupedUsers.push(sortedEntries.splice(0, r));
	})

	data['contributorsColumns'] = groupedUsers;

	return data;
}

function httpsPost({body, ...options}) {
	return new Promise((resolve,reject) => {
		const req = https.request({
			method: 'POST',
			...options,
		}, res => {
			const chunks = [];

			res.on('data', data => chunks.push(data))
			res.on('end', () => {
				let body = Buffer.concat(chunks);

				switch(res.headers['content-type']) {
					case 'application/json':
					try {
						body = JSON.parse(body);
					} catch (e) {
						console.log('Failed to parse reponse, retrying...');
						if (retries < maxRetry) {
							retries += 1;
							console.log('Attempt ' + retries);
							postRequest()
						}
					}
					break;
				}

				resolve(body)
			})
		})
		req.on('error',reject);

		if (body) {
			req.write(body);
		}

		req.end();
	})
}

function postRequest() {
	console.log('Fetching data.....')

	httpsPost({
		hostname: 'kenfdev.o6s.io',
		port: 443,
		path: '/github-stats',
		method: 'POST',
		headers: {
			'Content-Type': 'application/json'
		},
		body: JSON.stringify({
			org: 'openfaas'
		})
	}).then(resp => {
		const sorted = sortContribs(resp);

		fs.writeFile('_data/github_stats.json', JSON.stringify(sorted), 'utf8', () => {
			console.log('Github stats file generated');
		});
	}).catch(err => {
		console.log(err);
	})
}

postRequest()
