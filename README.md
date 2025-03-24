[![Build Status](https://api.travis-ci.com/virtualmin/virtualmin-awstats.svg?branch=master)](https://app.travis-ci.com/github/virtualmin/virtualmin-awstats)

# virtualmin-awstats
Virtualmin plugin to manage AWStats analytics and provide a UI for domain owners to view their own reports

![Virtualmin AWStats Configuration](http://i.imgur.com/tcpWqSQ.png)

![Virtualmin AWStats Report](http://i.imgur.com/LFEjp7T.png)

# Installation

# Installation

If you have installed Virtualmin using the install.sh installation script (which is the strongly recommended way to install Virtualmin), you already have this module, and can find it in the Logs and Reports category in the domain menu.

If you don't have Virtualmin, and don't want it, you can still get this module by downloading the appropriate package for your platform from:

For RHEL/CentOS/Scientific Linux or other RPM-based Linux distributions:

http://software.virtualmin.com/gpl/universal

For Debian/Ubuntu or other deb-based distributions:

http://software.virtualmin.com/gpl/debian/dists/virtualmin-universal

For other Linux or UNIX variants, the Webmin package format:

http://software.virtualmin.com/gpl/wbm

# Usage

Click *AWStats Reports* in the *Logs and Reports* menu for your domain. To alter the configuration of AWStats, such as enabling AWStats plugins, selecting reporting levels, etc. browse to *AWStats Configuration* in the same menu.

You can configure whether Virtualmin provides access to the AWStats module in the *Features and Plugins* page (in *System Settings*), and you can configure system-wide AWStats details from the *Configure* button on that page.
