/*------------HTTP request helper-------------*/
/*--------------------------------------------*/
function sendRequest(url, postData, method, callback) {
    var req = createXMLHTTPObject();

    if (!req) {
        return
    }

    req.open(method, url, true);

    if (postData) {
        req.setRequestHeader('Content-type','application/json');
    }

    req.onreadystatechange = function () {
        if (req.readyState != 4) {
            return
        }

        if (req.status != 200 && req.status != 304) {
            return;
        }

        callback(req);
    }

    if (req.readyState == 4) {
        return
    }

    req.send(postData);
}

var XMLHttpFactories = [
    function() { return new XMLHttpRequest() },
    function() { return new ActiveXObject('Msxml2.XMLHTTP') },
    function() { return new ActiveXObject('Msxml3.XMLHTTP') },
    function() { return new ActiveXObject('Microsoft.XMLHTTP') }
];

function createXMLHTTPObject() {
    var xmlhttp = false;

    for (var i = 0; i < XMLHttpFactories.length; i++) {
        try {
            xmlhttp = XMLHttpFactories[i]();
        }
        catch(e) {
            continue;
        }
        break;
    }

    return xmlhttp;
}


/*------------Gets github stars counter-------------*/
/*--------------------------------------------------*/

function getGithubStars() {
    var starsCounterWrapper = document.getElementById('git-stars');
    var counter = document.getElementById('stars-counter');

    try {
        sendRequest('https://api.github.com/repos/openfaas/faas', null, 'GET', function(resp) {
            starsCounterWrapper.classList.add('visible');

            if (resp && resp.stargazers_count) {
                var stars = String(resp.stargazers_count);

                counter.innerText = stars.split(/(?=(?:\d{3})+(?:\.|$))/g).join(',');
            }
        })
    } catch (e) {
        starsCounterWrapper.classList.add('visible');
    }
}

/*-------------Shrinks the top navbar---------------*/
/*--------------------------------------------------*/

function shrinkNav() {
    var nav = document.getElementById('top-nav');
    var htmlTag = document.documentElement;

    var maxHeight = 184;
    var minHeight = 80;

    var scrolled = window.scrollY;

    if (scrolled === 0) {
        nav.style.height = maxHeight + 'px';
        htmlTag.style.paddingTop = maxHeight + 'px';
        return;
    }

    if (scrolled >= maxHeight) {
        nav.style.height = minHeight + 'px';
        htmlTag.style.paddingTop = minHeight + 'px';
        return;
    }

    var height = Math.max(maxHeight - scrolled, minHeight) + 'px';

    nav.style.height = height;
    htmlTag.style.paddingTop = height;
}

window.addEventListener('scroll', function() {
    shrinkNav();
});

/*------------Init scripts on pageload--------------*/
/*--------------------------------------------------*/
document.addEventListener('DOMContentLoaded', function() {
    shrinkNav();
})
