strands_webtools
================

An interface to access the real and/or simulated robot via web applications. It is suggested that you run the server on a separate computer and have that computer connect to the robot's roscore, e.g. by setting `export ROS_MASTER_URI="http://robot-ip:11311/"` accordingly.


# Useful Information

 * Slides from ROSCon talk: [here](https://speakerdeck.com/baalexander/introduction-to-robot-web-tools)

 * Source of examples from ROSCon talk: [here](https://github.com/baalexander/roscon2013-examples)

 * ROS requirements on Ubuntu: 
```
rosdep -y install -r strands_webtools
```
* ROS requirements from source (e.g. OS X): rosbridge_suite, rosauth, tf2_web_republisher, mjpeg_server, robot_pose_publisher




# Running as standalone (not as part of a web server)
1. `roslaunch strands_webtools webtools.launch`
2. (optional) `rosrun topic_republisher republish_ptu_jointstate.py` (republishes the PTU joint state on `/ptu`, only needed for MORSE; The package [topic_republisher](https://github.com/strands-project/strands_utils/tree/master/topic_republisher) can be found in the [strands_utils](https://github.com/strands-project/strands_utils) repository)
3. Open in web browser: [http://localhost/](http://localhost/)

# Running the webtools behind a firewall in Apache (for the marathon)

## Install Apache2
 * ```sudo apt-get install apache2 libapache2-mod-proxy-html```
 * install the [mod_wstunnel](http://www.amoss.me.uk/2013/06/apache-2-2-websocket-proxying-ubuntu-mod_proxy_wstunnel/) for apache (the script `roscd strands_webtools; sudo ./build_wstunnel.sh` automates the following)
     ```
# Check apache version (should be 2.2.20 as of writing, if not adjust the next step)
dpkg -s apache2
# Checkout apache source
svn checkout http://svn.apache.org/repos/asf/httpd/httpd/tags/2.2.20/ httpd-2.2.20 
# Get patch and apply it
wget http://cafarelli.fr/gentoo/apache-2.2.24-wstunnel.patch
cd httpd-2.2.20
patch -p1 < ../apache-2.2.24-wstunnel.patch
## Build Apache 
svn co http://svn.apache.org/repos/asf/apr/apr/branches/1.4.x srclib/apr
svn co http://svn.apache.org/repos/asf/apr/apr-util/branches/1.3.x srclib/apr-util
./buildconf
./configure --enable-proxy=shared --enable-proxy_wstunnel=shared
make
## Copy the module and recompiled mod_proxy (for new symbols) to the ubuntu apache installation and update the permissions to match the other modules
sudo cp modules/proxy/.libs/mod_proxy{_wstunnel,}.so /usr/lib/apache2/modules/
sudo chmod 644 /usr/lib/apache2/modules/mod_proxy{_wstunnel,}.so
echo -e "# Depends: proxy\nLoadModule proxy_wstunnel_module /usr/lib/apache2/modules/mod_proxy_wstunnel.so" | sudo tee -a /etc/apache2/mods-available/proxy_wstunnel.load

      ```
  * Afterwards, run:  `sudo a2enmod proxy* rewrite*`
      
## ROS setup
The marathon branch requires STRAND's own version of rosbridge_suite and mjpeg_server to added security features. Here's the rosinstall config:
```
- git: 
   local-name: rosbridge_suite
   uri: 'https://github.com/strands-project/rosbridge_suite.git'
   version: readonly_capabilities
   
- git: 
   local-name: mjpeg_server
   uri: 'https://github.com/strands-project/mjpeg_server.git'
   version: groovy-devel
```

## Network and Server setup:

The setup is as follows:
* There is a webhost called *WH* in the following, which is accessible from the internet on port 80, which fulfills these requirements:
  * has Ubuntu 12.04LTS 64bit
  * runs (part of) the STRANDS ROS system (everything in strands_webtools is the minimum) and it can  connect to the robot's network
  * it has a firewall in place to ensure that it only accepts port 80 from the outside worlds, but accepts everything from the robot (I use `ufw` to configure this easily)
* There is the robot, called *Linda* here, that can connect to that server on all ports
* *WH* uses *Linda*'s `ROS_MASTER_URI` which needs to be configured to e.g. `export ROS_MASTER_URI=http://linda:11311`
* On *WH* the html, css, etc. files are served in a dedicated repository, e.g. `/opt/strands/lib/www` is assumed in the following.
* Apache needs to be configured to serve the files and act as a reverse proxy to allow to access ROS via port 80. Here's the Lincoln working file that resides under `/etc/apache2/available-sites/strands.site`
```
<VirtualHost *:80>
	DocumentRoot /var/www/
  # this tells apache that everything under "linda" is served from another location... that's where your html files should be
	Alias /linda /opt/strands/lib/www

	# just entering the server name will take you to your institutions website
	RedirectMatch permanent ^/$ http://robots.lincoln.ac.uk/
	
	# disable listing of directories in the strands dir
	<Directory /opt/strands/lib/www>
		Options -Indexes		
	</Directory>
	
	# rewrite engine is needed for the reverseproxy things to work
	RewriteEngine On
	
	Options -Indexes
	
	
	# serving mjpeg image streams under this URL. This needs to match the URL given in the HTML file. the mjpeg_server is running locally on port 8181 (as specified in the launch file)
	RewriteRule ^/linda/video http://localhost:8181/ [P]
	
  # reverse proxy for rosbridge (rosbridge is running locally on port 9090 (as specified in the launch file)
  ProxyPass /linda/rosws ws://localhost:9090/
  ProxyPassReverse /linda/rosws ws://localhost:9090/	
</VirtualHost>
```


You may want to adapt this (e.g. change 'linda' for something else), but be aware to change the `marathon.html` file correspondingly.

## Running it
* run all the nodes on the robot, e.g. openni, mapserver, etc.
* On the robot make sure you run the nodes that throttle the network traffic:
`roslaunch strands_webtools webtools_robot.launch` You want to include this in your usual robot setup. It just advertises a few other topics that have low bandwidth that *WH* is then connecting to.
* On *WH* run `roslaunch strands_webtools webtools_safe.launch` with `ROS_MASTER_URI=http://linda:11311/` (or whatever your robot is called, e.g. just its IP address)
* goto the external URL (e.g. http://lcas.lincoln.ac.uk/linda/marathon.html) and check if everythin works



