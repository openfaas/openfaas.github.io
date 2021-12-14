/*--------------Initialize youtube api--------------*/
/*--------------------------------------------------*/

var videoId = 'ZnZJXI377ak';
var playerControl = document.getElementById('yt-player-play');
var sampleVideo = document.getElementById('sample-video');
var play = null;
var stop = null;

// landingPlayer is initialized in main.js and set as global variable

function initYoutubePlayer() {
    // playerControl.addEventListener('click', function() {

    //     console.log("Got here")
    // })
}

/*------------Init scripts on pageload--------------*/
/*--------------------------------------------------*/
document.addEventListener('DOMContentLoaded', function() {
    initYoutubePlayer();
})
