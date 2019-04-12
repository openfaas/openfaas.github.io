/*--------------Initialize youtube api--------------*/
/*--------------------------------------------------*/

var player = null;
var videoId = 'yOpYYYRuDQ0';
var playerControl = document.getElementById('yt-player-play')
var play = null;
var stop = null;

function onPlayerReady(event) {
    event.target.playVideo();
}

function playVideo() {
    player.playVideo();
    player.a.classList.add('playing');
}

function onYouTubeIframeAPIReady() {
    player = new YT.Player('yt-player-iframe', {
        videoId: videoId,
        playerVars: { 'autoplay': 0, 'controls': 1 },
        events: {
            'onReady': function(e) {
                e.target.a.classList.add('ready')
            },
            'onError': function(err) { console.log(err);}
        }
    });
}

function initYoutubePlayer() {
    var tag = document.createElement('script');
    var firstScriptTag = document.getElementsByTagName('script')[0];

    tag.src = "https://www.youtube.com/iframe_api";
    firstScriptTag.parentNode.insertBefore(tag, firstScriptTag);

    playerControl.addEventListener('click', function() {
        playVideo();
    })
}

/*------------Init scripts on pageload--------------*/
/*--------------------------------------------------*/
document.addEventListener('DOMContentLoaded', function() {
    initYoutubePlayer();
})
