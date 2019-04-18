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

/*------------Init scripts on pageload--------------*/
/*--------------------------------------------------*/
document.addEventListener('DOMContentLoaded', function() {
    shrinkNav();
    initNavToggler();
})
