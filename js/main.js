/*-------------Shrinks the top navbar---------------*/
/*--------------------------------------------------*/

function shrinkNav() {
    var nav = document.getElementById('top-nav');
    var htmlTag = document.documentElement;

    var maxHeight = 184;
    var minHeight = 80;

    if (window.innerWidth <= 1080) {
        maxHeight = 110;
    }

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

window.addEventListener('resize', function() {
    shrinkNav();
});

/*----------Add navbar menu toggle action-----------*/
/*--------------------------------------------------*/

function initNavToggler() {
    var toggler = document.querySelector('.navbar-burger');
    var menu = document.querySelector('.navbar-menu');

    toggler.addEventListener('click', function() {
        toggler.classList.toggle('is-active');
        menu.classList.toggle('is-active');
    });
}

initNavToggler();

/*------------Init youtube player modal-------------*/
/*--------------------------------------------------*/

var videoId = 'ZnZJXI377ak';
function initVideoModal() {
    var triggers = document.querySelectorAll('.start-demo-video');

    var modal = document.createElement('div');
    modal.className = 'modal modal-youtube';

    var background = document.createElement('div');
    background.className = 'modal-background';

    var content = document.createElement('div');
    content.className = 'modal-content';

    var player = document.createElement('div');
    player.id = 'modal-player';

    var close = document.createElement('button');
    close.className = 'modal-close is-large';

    modal.appendChild(background);
    content.appendChild(player);
    modal.appendChild(content);
    modal.appendChild(close);

    document.body.appendChild(modal);

    function showModal(visible) {
        if (visible) {
            modal.classList.add('is-active');
            modalPlayer.playVideo();
        } else {
            modal.classList.remove('is-active');
            modalPlayer.stopVideo();
        }
    }

    Array.from(triggers).forEach(function(el) {
        el.addEventListener('click', function() {
            showModal(true);
        });
    });

    close.addEventListener('click', function() {
        showModal(false);
    });

    background.addEventListener('click', function() {
        showModal(false);
    });
}
