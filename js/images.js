
// Image names are stored here.
var images = [];

// Relative path to images we'll be showing.
var imageDirectory = "img/sync/";

// Image index that we are going to display.
var currentImageIndex = 0;

// Scan for new images by executing the cgi-script once an hour.
var scanInterval = setInterval(scanImages, 3600000); // Every 3600 seconds.

// Timer that fires to load next image.
var imageInterval = null;

// Every 30 seconds.
var intervalTime = 30000;
var rescanDelayMs = 10000;
var rescanTimeout = null;

function buildImageUrl(imageFilename) {
  return new URL(imageDirectory + imageFilename, window.location.href).toString();
}

function showSplash() {
  $('#gif').css({ "background-image": ("url(/img/splash.png)") });
}

function scheduleRescan() {
  if (rescanTimeout != null) {
    return;
  }
  rescanTimeout = setTimeout(function() {
    rescanTimeout = null;
    scanImages();
  }, rescanDelayMs);
}

function scanImages() {
  $.ajax({
    type:'get',
    url: '/cgi-bin/images.rb',
    dataType: 'json',
    success:function(data) {
      if (rescanTimeout != null) {
        clearTimeout(rescanTimeout);
        rescanTimeout = null;
      }
      currentImageIndex = -1;
      images = data;
      resetImageTimer();
    },
    error:function(data) {
      console.log("There was an error calling /cgi-bin/images.rb, does the folder image/sync exist?")
      scheduleRescan();
    }
  });
}

// Kicks off the timer, or cancels the running timer and kicks off a new one.
function resetImageTimer() {
  // This only happens on load of page.
  if (imageInterval == null) {
    loadNextImage()
    imageInterval = setInterval(loadNextImage, intervalTime); // Every `intervalTime`
    return;
  }

  clearInterval(imageInterval);
  imageInterval = setInterval(loadNextImage, intervalTime); // Every `intervalTime`
}

function removeMissingImage(imageFilename) {
  var index = images.indexOf(imageFilename);
  if (index === -1) {
    return;
  }
  images.splice(index, 1);
  if (index <= currentImageIndex && currentImageIndex > 0) {
    currentImageIndex -= 1;
  }
  if (currentImageIndex >= images.length) {
    currentImageIndex = 0;
  }
}

function preloadImage(imageUrl, onLoad, onError) {
  var img = new Image();
  img.onload = onLoad;
  img.onerror = onError;
  img.src = imageUrl;
}

function loadImage(newImage) {
  // If we can't find images, then either we just deleted all of them or the server setup isn't complete.
  if (images.length < 1 || !newImage) {
    showSplash();
    scheduleRescan();
    return;
  }

  var path = buildImageUrl(newImage);

  $('#gif').removeClass("visible");
  $('#gif').addClass("hidden");
  // code before the pause
  preloadImage(path, function() {
    setTimeout(function(){
      $('#gif').css({ "background-image": ("url(" + path + ")") });
      $('#gif').addClass("visible");
      $('#gif').removeClass("hidden");
    }, 500);
  }, function() {
    console.log("Server missing data: " + newImage);
    removeMissingImage(newImage);
    if (images.length < 1) {
      showSplash();
      scheduleRescan();
      return;
    }
    setTimeout(loadNextImage, 0);
  });
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
setTimeout(function() { location.reload(); }, 21600000);
