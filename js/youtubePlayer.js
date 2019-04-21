/*--------------Initialize youtube api--------------*/
/*--------------------------------------------------*/

var videoId = 'yOpYYYRuDQ0';
var playerControl = document.getElementById('yt-player-play');
var sampleVideo = document.getElementById('sample-video');
var play = null;
var stop = null;

// landingPlayer is initialized in main.js and set as global variable

function onPlayerReady(event) {
    console.log('here')
    event.target.playVideo();
}

function playVideo() {
    landingPlayer.playVideo();
    landingPlayer.a.classList.add('playing');
    sampleVideo.classList.add('is-hidden');
}

function initYoutubePlayer() {
    playerControl.addEventListener('click', function() {
        playVideo();
    })
}

/*------------Init scripts on pageload--------------*/
/*--------------------------------------------------*/
document.addEventListener('DOMContentLoaded', function() {
    initYoutubePlayer();
})
