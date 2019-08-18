
// Image names are stored here.
var images = [];

// Relative path to images we'll be showing.
var imageDirectory = "img/sync/"

// Image index that we are going to display.
var currentImageIndex = 0;

// Scan for new images by executing the cgi-script once an hour.
var scanInterval = setInterval(scanImages, 3600000); // Every 3600 seconds.

// Timer that fires to load next image.
var imageInterval = null;

// Every 15 seconds.
var intervalTime = 15000;
function scanImages(jQuery) {
  $.ajax({
    type:'get',
    url: '/cgi-bin/images.rb',
    success:function(data) {
      currentImageIndex = -1;
      images = data;
      resetImageTimer();
    },
    error:function(data) {
      console.log("There was an error calling /cgi-bin/images.rb, does the folder image/sync exist?")
    }
  });
}

// Kicks off the timer, or cancels the running timer and kicks off a new one.
function resetImageTimer() {
  // This only happens on load of page.
  if (imageInterval == null) {
    loadNextImage()
    imageInterval = setInterval(loadNextImage, intervalTime); // Every 15 seconds
    return;
  }

  clearInterval(imageInterval);
  imageInterval = setInterval(loadNextImage, intervalTime); // Every 15 seconds
}

function isImageExist(imageFilename) {
  var http = new XMLHttpRequest();
  http.open('HEAD', window.location.href + imageDirectory + imageFilename, false);
  http.send();
  var exists = http.status == 200;

  if (!exists) {
    console.log("Server missing data:" + img.src)
  }
  return exists
}

function loadImage(newImage) {
  // If we can't find images, then either we just deleted all of them or the server sertup isn't complete.
  // If image doesn't exist, the image folder probably just synced. It's easiest to just reload the page knowing
  // that the reload will pick up the changes and put us into a known state.
  if (images.length < 1 || !isImageExist(newImage)) {
    $('#gif').css({ "background-image": ("url(img/splash.png)") });
    setTimeout(function () {
      location.reload(true);
    }, 10000);
    return 
  }

  var path = imageDirectory + newImage;

  $('#gif').removeClass("visible");
  $('#gif').addClass("hidden")
  //code before the pause
  setTimeout(function(){
    $('#gif').css({ "background-image": ("url(" + path + ")") });
    $('#gif').addClass("visible");
    $('#gif').removeClass("hidden")
  }, 500);
}

// Loads the next image from `images` using `currentImageIndex`
function loadNextImage() {
  currentImageIndex += 1;
  if (currentImageIndex >= images.length) {
    currentImageIndex = 0;
  }

  var nextImage = images[currentImageIndex];
  loadImage(nextImage);
}

// Loads the previous image from `images` using `currentImageIndex -1`
function loadPreviousImage() {
  currentImageIndex -= 1;
  if (currentImageIndex < 0) {
    currentImageIndex = images.length - 1;
  }

  var previousImage = images[currentImageIndex];
  loadImage(previousImage);
}

// Startup only run once per document load.
function initializeView() {
  var width = $(window).width();
  var height = $(window).height();
  // It's trash but Chromium doesn't get smaller than 500px, so we need to detect
  // when we are running on a 320x480 screen and adjust accordingly.
  if (width == 500 && height == 480) {
    $('#gif').css({ "width": "320px", "height": "480px" });
  } else {
    $('#gif').css({ "width": "100%", "height": "100%" });
  }

  scanImages();
}

$(document).ready(initializeView);

// Restart after 6 hours to pick up any changes in git.
setTimeout("location.reload(true);", 21600000);
