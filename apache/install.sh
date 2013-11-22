#!/bin/bash

set -x

scitos_desc=`rospack find scitos_description`
webtools=`rospack find strands_webtools`
apache_doc_root="/opt/strands/lib/www/"
apache_avail_sites="/etc/apache2/sites-available"

sudo install -d $apache_doc_root

installdirs="css keyboardteleopjs mjpegcanvasjs nav2djs ros2djs ros3djs roslibjs js"
for d in $installdirs; do
	sudo cp -af $webtools/$d/ $apache_doc_root/$d
done

find $webtools -name "build" -type d | xargs -i sudo cp --parents -af {} $apache_doc_root/
find $webtools -name "include" -type d | xargs -i sudo cp --parents -af {} $apache_doc_root/

sudo install -d $apache_doc_root/scitos_description

sudo cp -af $scitos_desc/meshes $apache_doc_root/scitos_description

sudo install -p *.png *.html $apache_doc_root

sudo chown -R www-data:www-data $apache_doc_root

sudo service apache2 reload

