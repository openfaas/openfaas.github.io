/*--------------Initialize youtube api--------------*/
/*--------------------------------------------------*/

var videoId = 'ZnZJXI377ak';
var playerControl = document.getElementById('yt-player-play');
var sampleVideo = document.getElementById('sample-video');
var play = null;
var stop = null;

// landingPlayer is initialized in main.js and set as global variable

function onPlayerReady(event) {
    console.log('Video player ready')
    event.target.playVideo();
}

function playVideo() {
    if(document.landingPlayer) {
        document.landingPlayer.playVideo();
        document.landingPlayer.f.classList.add('playing');
        sampleVideo.classList.add('is-hidden');
        playerControl.classList.add('is-hidden');
    }
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
