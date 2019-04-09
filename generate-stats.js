const https = require('https');
const fs = require('fs');

function sortContribs(data) {
	data.byLogin = Object.entries(data.byLogin).sort((a, b) => b[1] - a[1]).reduce((a, b) => { a[b[0]] = b[1]; return a }, {})

	return data;
}

function httpsPost({body, ...options}) {
	console.log('Fetching data.....')
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
					body = JSON.parse(body);
					break;
				}
				resolve(body)
			})
		})
		req.on('error',reject);
		if(body) {
			req.write(body);
		}
		req.end();
	})
}

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
	const sorted = sortContribs(resp)
	fs.writeFile('_data/github_stats.json', JSON.stringify(sorted), 'utf8', () => {
		console.log('Github stats file generated');
	});
}).catch(err => {
	console.log(err)
})
