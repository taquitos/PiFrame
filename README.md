# PiFrame: An auto-updating Raspberry Pi-based picture frame.
[![Twitter: @taquitos](https://img.shields.io/badge/contact-@taquitos-orange.svg?style=flat)](https://twitter.com/FastlaneTools)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)

Learn how to build a tiny self-contained picture frame that syncs images with [your choice of supported cloud storage providers](https://rclone.org). The frame self-updates for any new PiFrame code and supports tapping on the screen for navigating forward and back through your photos.

![PiFrame example showing an animated gif on a 3.5 inch screen](https://i.imgur.com/V3NM7HA.gif "A PiFrame in action!")

## Motivation:
We had a kid and my extended family wants to stay updated with the latest and greatest kid pictures. I wanted to give them something that would always stay up-to-date as I added or removed pictures and required zero setup (other than WiFi info) from family members who might not be as tech-savvy as I am. Ideally, they plug in the device and it just works. On my side, I wanted to be able to drop some photos somewhere and have them picked up automatically by the photo frame. While there are many frames that do allow for this type of behavior, I decided not to take a chance on them because they all probably talk to some foreign server about my photos and frame usage as well as leaking [PII](https://en.wikipedia.org/wiki/Personal_data). Furthermore, once I saw I could get a tiny screen, I loved the idea of having a little picture frame that rotated through a bunch of gifs on my desk.

# Table of contents
1. [Materials](#materials)
2. [Which Pi?](#which_pi)
3. [The screen](#screen)
4. [How-to](#howto)
	* [Enabling SSH on the Pi](#ssh)
	* [Putting the frame together](#construction)
	* [Don’t have a keyboard, mouse, or monitor?](#no_keyboard)
		* [Connect to your pi over SSH](#connect_ssh)
	* [Have a USB keyboard, mouse, and HDMI monitor?](#keyboard)
5. [Installing and configuring all required software](#installing)
	* [First things first](#first) 
	* [Install Pi hat LCD drivers](#pi_hat)
6. [Configure the desktop to be a kiosk](#kiosk)
	* [Update wireless configuration](#wifi)
	* [Install rclone](#rclone)
	* [Configure rclone remote](#rclone_config)
	* [Install Apache](#apache)
	* [Install Ruby](#ruby)
	* [Install the PiFrame code!](#frame)
	* [Configuring auto-update](#auto_update)
	* [Changing window manager background](#background)
7. [Optional: Optimizing power usage and reducing heat](#optimizing)
8. [Tools: Preparing GIFs](#tools_gifs)

<a name="materials"></a> 
## Materials: 
Specific details about each material is below, but here’s a quick reference list.

* Pi 3B or 3B+
* Micro sd card with the [latest and greatest Raspbian](https://raspbian.org/RaspbianImages) installed. I use a 32gb card. Any size is fine, just make sure it doesn't fill up. 
* [3.5 inch touch screen with case](https://www.amazon.com/gp/product/B07N38B86S).
  * You can use the official 7” screen, in-fact I use that for one frame. It also means you get to skip the LCD driver setup section of this guide.

**Note:** There are a ton of tutorials online that show how to get your downloaded Raspbian image onto an sd card, so I’ll be skipping the details on that. Personally, I use a mac, so I downloaded from [https://www.raspberrypi.org/downloads/raspbian/](https://www.raspberrypi.org/downloads/raspbian/) and then used Etcher ([https://www.balena.io/etcher/](https://www.balena.io/etcher/)) to image it to an sd card.

<a name="which_pi"></a> 
## Which Pi?
The 3B is great- it uses less power and doesn’t seem to get as warm, but it lacks the dual-band 820.11ac WiFi that the 3B+ has. I’ve used both for this, so really, it’s whatever you want. Also, in an attempt to reduce heat and power usage, we will be adjusting the CPU speed as part of this guide. Overall, the 3B is my personal preference since it runs cooler, I don’t need a fast internet connection, and seems to draw less power. These folks have done [some comparative tests between the 3B and 3B+](https://core-electronics.com.au/tutorials/raspberry-pi-3-model-b-plus-performance-vs-3-model-b.html) that confirm lower power draw. That being said, in order to maximize compatibility for my family, I’m choosing to send them 3B+’s. 

<a name="screen"></a> 
## The screen:
The screen is an interesting beast. There are a number of 3.5 inch screens that connect in a couple different ways. The preferred screen connects directly to the Pi as a hat ([uses SPI](https://en.wikipedia.org/wiki/Serial_Peripheral_Interface)). You don’t need to connect anything else, and touch also JustWorks(™). There are other 3.5 screens that require you connect the screen to the Pi with a special small HDMI part. While those are probably better (less screen lag), I haven’t been able to find a case that looks clean and professional-ish for my family that has room for the weird HDMI part. if you want to design a 3d-printed one, I’d happily print one out and test for you 😉. The particular touchscreen I chose is sold together with a stylus, 3 heat sinks, a terrible screwdriver, and an equally terrible pair of tweezers. The quality of the LCD is meh, but it works.

<a name="howto"></a> 
## How-to:
<a name="ssh"></a> 
### Enabling SSH on the Pi
Before you go and power it on, you’ll want to enable SSH. Plug the SD card into your computer and navigate to the volume labeled “boot”. Create a file named “ssh”. If you’re using a Mac, you can also do this in the terminal:

`touch /Volumes/boot/ssh`

Now eject the media.

<a name="construction"></a> 
### Putting the frame together
Put your sd card with Raspbian on it into the Pi. You can also go ahead and put the heat sinks on that were included and then place the Pi in the case. You'll want to screw it in with the 4 included screws. After, put the LCD hat on the Pi and close it all up.

If you have ethernet available, plug it in.

If you have an HDMI monitor, a USB keyboard, and mouse available, plug them in. If you don’t, you will need to plug the Pi into your router using an ethernet cable so that you can use SSH to continue the setup. If you have a screen and keyboard plugged in, go ahead and power on the Pi.

<a name="no_keyboard"></a> 
### Don’t have a keyboard, mouse, or monitor?

<a name="connect_ssh"></a> 
#### Connect to your pi over SSH 
If you connected by ethernet and don’t have a keyboard, you can’t easily find out your IP address to SSH into. If you have access to your router, you can check the DHCP clients. Look for a MAC address that starts with `B8:27:EB` this is likely the pi on your network.
You can login using:
 
`ssh pi@<ip address>` ***Note:*** the password is `raspbian`

<a name="keyboard"></a> 
### Have a USB keyboard, mouse, and HDMI monitor?
Go ahead and open open up a terminal, there should be an icon in the menu bar for that.

<a name="installing"></a> 
## Installing and configuring all required software

<a name="first"></a> 
### First things first
There are a few things you’ll want to do right away:

* Change the password: `passwd pi`
* Use ssh public key auth so you don’t have to use the password anymore. [A good how-to](https://serverpilot.io/docs/how-to-use-ssh-public-key-authentication), but make sure you do this locally, not on your pi.
  * While they suggest you use a password on your private key, I don’t, that way it’s easier for me to login (no password required at all)

Once you’ve created your keys, you can use

`ssh-copy-id pi@<Pi address>`

To copy over the key from your local machine to your Pi. From here on out, you won't need to enter the password for the frame if you SSH into it 🔐🎉

<a name="pi_hat"></a> 
### Install Pi hat LCD drivers
**Caveat:** If you’re using a USB keyboard, mouse, and HDMI monitor, I would skip this step and come back to it after everything else is done. I don’t think you can use an HDMI monitor with your LCD screen at the same time, and it's much nicer to use an external monitor to finish setup than it is to use SSH, but that's my two cents.
 
Grab the drivers for your LCD hat. 

```
cd ~
git clone https://github.com/goodtft/LCD-show.git
```
Enable the scripts to be executable

`chmod -R 755 LCD-show`

I just `chmod` the whole directory recursively, it's not best practice and you can be more picky about this if you’d like, but in practice this won’t matter so #YOLO 🤘.

Run the install script, **reminder:** I don’t think you can use your HDMI monitor at the same time.

`sudo ./LCD-show/MHS35-show` 

At this point, the device will reboot and you’ll see the Raspbian boot screen on the LCD 🎉

If the screen is rotated in a direction you don’t like (I prefer my frame to be in portrait), you can change that, but warning: it reboots after you run it, so be sure you that’s ok before you run the command:

`. ~/LCD-show/rotate.sh 270 (or 90/180)`

<a name="kiosk"></a> 
## Configure the desktop to be a kiosk
You’ll probably want to get rid of the mouse cursor when it’s not in use, the menu bars, the splash screen as the desktop manager loads, the screensaver, and disable power-saving features that turn off the screen. This way the Pi boots directly into a super clean desktop that doesn’t obviously allow you to do anything (other than loading up your picture frame).

Install unclutter, this makes the mouse pointer disappear when not in use.

`sudo apt install -y unclutter`

Install [chromium](https://www.chromium.org/Home), this will be what displays your pictures in borderless mode.

`sudo apt install -y chromium-browser`

Create configuration folder.

`mkdir -p ~/.config/lxsession/LXDE-pi`

Create autostart file- this gets run every time your desktop manager boots up.

`nano ~/.config/lxsession/LXDE-pi/autostart`

Add the following to the autostart file:

```
@unclutter -idle 0
@pcmanfm --desktop --profile LXDE-pi
@xscreensaver -no-splash
@xset s off
@xset -dpms
@xset s noblank
@chromium-browser --disable-infobars --incognito --kiosk http://localhost/
```

Save the autostart file. 

In order to hide the 🗑️(Trash) icon or any mounted filesystem icons, you’ll need to:

`nano ~/.config/pcmanfm/LXDE-pi/desktop-items-0.conf`

And set the following values

```
show_trash=0
show_mounts=0
```

<a name="wifi"></a> 
### Update wireless configuration
For wireless networking, you’ll want to add your own networks as well as those of your family.

`sudo nano /etc/wpa_supplicant/wpa_supplicant.conf`

And add the following:

```
network={
        ssid="My WiFi Name"
        scan_ssid=1
        key_mgmt=<encryption type (e.g., WPA-PSK)>
        psk="<my network password>"
}
```
If you want to add multiple networks, duplicate this block, including the `“network=”` portion and edit it. There’s no need for commas between the networks, just literally copy/paste the block. The order of WiFi searching is top-down. If you want to test this, reboot the Pi and unplug your ethernet. You’ll need to then go back to your router and find your IP address again. From here on out, you can SSH into the PI using its WiFi.

<a name="rclone"></a> 
### Install rclone
I use rclone to sync images from BackBlaze down to my Pi. It supports a bunch of providers including s3 and Google Drive. I was already using BackBlaze. If I weren’t, I’d probably suggest s3.

`sudo apt install -y rclone`

<a name="rclone_config"></a> 
### Configure rclone remote
This will configure rclone for BackBlaze, the steps are very similar for other providers. The rclone website provides a bunch of help if you need it. Here’s what I did:

`rclone config`
This command presents you with a setup flow asking the following questions (for BackBlaze, in my case)

`Name:` This is the name of your rclone configuration. I chose `GifsTallConfig` because my screen will be tall, and I want to use the tall gif bucket I set up.

`Choose a number from below, or type in your own value:` I picked `5` (for BackBlaze, there's a list that displays and you can pick from it).

`Application Key ID:` This came from my BackBlaze Bucket configuration.

`Application Key:` This also came from my BackBlaze Bucket configuration.

`hard_delete:` `true`(so when I update the bucket, it deletes the old files from my pi.

`Edit advanced config?:` `no`

`Is this OK?:` `Yes`

To test this setup, you need to know the specifics of the buckets you set up on BackBlaze. I created one on BackBlaze called `GifsTall`. So I’ll tell rclone to use the config `GifsTallConfig` that I just setup above, with the new remote bucket named `GifsTall` to pull down the contents of that bucket to where apache will be serving images from `/var/www/html/img/sync`, but first I must create this directory on my Pi:

`mkdir -p /var/www/html/img/sync `

Now I can initiate the first sync:

`rclone sync "GifsTallConfig":GifsTall /var/www/html/img/sync`

This should complete successfully if you used the correct rclone config and BackBlaze bucket.

<a name="apache"></a> 
### Install Apache
`sudo apt install -y apache2`

Once that completes, you’ll need to link the apache cgi mod so we can run some code that generates a list of images to display when the webpage loads.

`sudo ln -s /etc/apache2/mods-available/cgi.load /etc/apache2/mods-enabled/`

Copy over the available configuration into the enabled folder.

`sudo cp /etc/apache2/conf-available/serve-cgi-bin.conf /etc/apache2/conf-enabled/`

Since we’re only going to serve one webpage and one cgi script, we can simplify the config by editing:

`sudo nano /etc/apache2/conf-enabled/serve-cgi-bin.conf`

Find the the following:

```
ScriptAlias /cgi-bin/ /usr/lib/cgi-bin/
                <Directory "/usr/lib/cgi-bin">
```            

Change that so it references the path where the frame cgi script will exist:

```
 ScriptAlias /cgi-bin/ /var/www/html/cgi-bin/
                <Directory "/var/www/html/cgi-bin">
```
Double check you updated the above *two* `/usr/lib/cgi-bin/` entries to `/var/www/html/cgi-bin/`.

Change the owner of your website to the user `pi` so you don’t need to sudo all the things all the time.

`sudo chown -R pi /var/www/html`

Delete the preinstalled index.html test website

`rm /var/www/html/index.html`

<a name="ruby"></a> 
### Install Ruby
Now that we’ve configure Apache and [mod_cgi](http://httpd.apache.org/docs/current/mod/mod_cgi.html), we’re going to be using that with Ruby. The best way I’ve found to install Ruby is with [rbenv](https://github.com/rbenv/rbenv). There are a lot of benefits to using rbenv.

Install rbenv

```
sudo apt install rbenv -y
rbenv init
echo 'eval "$(rbenv init -)"'>> ~/.bashrc 
source ~/.bashrc
```

rbenv works best with the `ruby-build` plugin, so let's make a directory for it and then install the plugin:

```
mkdir -p "$(rbenv root)"/plugins
git clone https://github.com/rbenv/ruby-build.git "$(rbenv root)"/plugins/ruby-build
```

Install a recent Ruby version, I use 2.5.5, this takes a while so put some tea 🍵 on.

`rbenv install 2.5.5`

When finished installing ruby 2.5.5, set it as global:

`rbenv global 2.5.5`

<a name="frame"></a> 
### Install the PiFrame code!
`git clone https://github.com/taquitos/PiFrame.git /var/www/html/.`

If you are SSH’d into the Pi, you can attach to the display and launch chromium to test it all out:

```
export DISPLAY=:0
chromium-browser --disable-infobars --incognito --kiosk http://localhost/
```

This should load up your images that you synced in the rclone steps above! If it doesn't you might have missed a step. 

<a name="auto_update"></a> 
### Configuring auto-update
Once everything is all set up and working, you can use cron to sync your images and your code. Specify that you want to use `nano` as your crontab editor *(optional)*, and then launch the editor:

`export VISUAL=nano; crontab -e`

Add the following

```
15 * * * * rclone sync "GifsTallConfig":GifsTall /var/www/html/img/sync >/dev/null 2>&1
0 */12 * * * cd /var/www/html; git pull origin master >/dev/null 2>&1
```
The first line syncs your images every 15 minutes, and the second syncs the `PiFrame` code with GitHub every 12 hours.

<a name="background"></a> 
### Changing window manager background
Want to change the default desktop background from the pre-installed one? Get yourself an image that is 480x320px, and then copy it over to the Pi using SCP:

`scp <folder-with-background>/background.jpg pi@<Pi IP address>:/home/pi/`

In my case, this was:

`scp ~/background.jpg pi@10.0.1.38:/home/pi/`

Next, SSH into the pi and run:

```
export DISPLAY=:0
pcmanfm --set-wallpaper="/home/pi/background.jpg"
```

**Note:** The desktop is only shown for a few seconds while the device is finishing loading up chromium-browser. It’s a nice touch to do this, but really doesn’t matter.

<a name="optimizing"></a> 
## Optional: Optimizing power usage and reducing heat
There are a few things you can do to attempt to reduce the amount of power you use and heat generated. By editing/adding some values in the /boot/config.txt file, we can configure our Pi to reduce the max speed, and also decrease the minimum speed. In this example, I'm using a pi3 B and decreasing the maximum clock speed by 200mhz (1200mhz to 1000mhz), and decreasing the minimum clock speed on pi3 B from 600mhz to 400mhz.

Add in the following lines to `/boot/config.txt` (make sure no duplicate lines exist):

```
arm_freq_min=400
arm_freq=1000 
```

Now reboot the pi (`sudo reboot`) and you’re done 😹!

<a name="tools_gifs"></a>
## Tools: Preparing GIFs
PiFrame will display any images you drop into `img/sync`, but animated GIFs look best when resized to your screen.
This repo includes a helper script that uses ImageMagick to resize and optimize animated GIFs.

Install ImageMagick (if needed). The script will attempt to install it automatically unless you pass `--no-install`:

`sudo apt install -y imagemagick`

Run the tool from the repo root (auto-detects portrait vs landscape per file). By default it reads from `./tools/input` and writes to `./tools/output`:

```
tools/prepare_gifs.sh
```

Common options:
* `--auto` (default) to detect orientation per file
* `--portrait` (320x480) or `--landscape` (480x320) to force an orientation
* `--fit contain|cover|stretch` (default: contain)
* `--out <dir>` (default: ./tools/output)
* `--no-pingpong` to keep the original playback (no reverse)
* `--colors <n>` (default: 128, use 0 to disable)
* `--no-dither` to disable dithering
* `--no-gifsicle` to skip extra optimization if `gifsicle` is installed
* `--no-install` to skip auto-installing dependencies
* `--format webp` to output animated WebP instead of GIF (still loops)
* `--webp-quality <n>` (default: 80) and `--webp-method <n>` (default: 6)

Supported resolutions: `320x480` (portrait) and `480x320` (landscape).

Animated WebP requires Chromium with WebP animation support.

If you want to write directly to the frame’s sync folder, you can do:

```
tools/prepare_gifs.sh --out img/sync ~/Downloads/gifs
```

See full usage:

`tools/prepare_gifs.sh --help`
