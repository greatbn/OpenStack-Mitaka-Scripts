
#!/bin/bash -ex
#
source config.cfg
source functions.sh

echocolor "Create database for manila"
sleep 3
mysql -u root -p$MYSQL_PASS -e"CREATE DATABASE manila;"
mysql -u root -p$MYSQL_PASS -e"GRANT ALL PRIVILEGES ON manila.* TO 'manila'@'localhost' IDENTIFIED BY '$MANILA_DBPASS';"
mysql -u root -p$MYSQL_PASS -e"GRANT ALL PRIVILEGES ON manila.* TO 'manila'@'%' IDENTIFIED BY '$MANILA_DBPASS';"

echocolor "Create user, endpoint, service manila"
sleep 3
openstack user create --domain default --password Welcome123 manila
openstack role add --project service --user manila admin
openstack service create --name manila \
  --description "OpenStack Shared File Systems" share
openstack service create --name manilav2 \
  --description "OpenStack Shared File Systems" sharev2
openstack endpoint create --region RegionOne \
  share public http://controller:8786/v1/%\(tenant_id\)s
openstack endpoint create --region RegionOne \
  share internal http://controller:8786/v1/%\(tenant_id\)s
openstack endpoint create --region RegionOne \
  share admin http://controller:8786/v1/%\(tenant_id\)s
openstack endpoint create --region RegionOne \
  sharev2 public http://controller:8786/v2/%\(tenant_id\)s
openstack endpoint create --region RegionOne \
  sharev2 internal http://controller:8786/v2/%\(tenant_id\)s
openstack endpoint create --region RegionOne \
  sharev2 admin http://controller:8786/v2/%\(tenant_id\)s

echocolor "Install manila-api, manila-scheduler on controller node"
sleep 3 
apt-get install manila-api manila-scheduler \
  python-manilaclient -y 
manila_ctl=/etc/manila/manila.conf

echocolor "config manila on controller node"
sleep 3
## [DEFAULT] section

ops_edit $manila_ctl DEFAULT rpc_backend rabbit
ops_edit $manila_ctl DEFAULT auth_strategy keystone
ops_edit $manila_ctl DEFAULT default_share_type default_share_type
ops_edit $manila_ctl DEFAULT rootwrap_config /etc/manila/rootwrap.conf
ops_edit $manila_ctl DEFAULT my_ip $CTL_MGNT_IP

## [database] section
ops_edit $manila_ctl database \
connection mysql+pymysql://manila:$MANILA_DBPASS@$CTL_MGNT_IP/manila

## [oslo_messaging_rabbit] section
ops_edit $manila_ctl oslo_messaging_rabbit rabbit_host $CTL_MGNT_IP
ops_edit $manila_ctl oslo_messaging_rabbit rabbit_userid openstack
ops_edit $manila_ctl oslo_messaging_rabbit rabbit_password $RABBIT_PASS

## [keystone_authtoken] section
ops_edit $manila_ctl keystone_authtoken auth_uri http://$CTL_MGNT_IP:5000
ops_edit $manila_ctl keystone_authtoken auth_url http://$CTL_MGNT_IP:35357
ops_edit $manila_ctl keystone_authtoken memcached_servers $CTL_MGNT_IP:11211
ops_edit $manila_ctl keystone_authtoken auth_type password
ops_edit $manila_ctl keystone_authtoken project_domain_name default
ops_edit $manila_ctl keystone_authtoken user_domain_name default
ops_edit $manila_ctl keystone_authtoken project_name service
ops_edit $manila_ctl keystone_authtoken username manila
ops_edit $manila_ctl keystone_authtoken password $MANILA_PASS

## [oslo_concurrency] section
ops_edit $manila_ctl oslo_concurrency lock_path /var/lib/manila/tmp

su -s /bin/sh -c "manila-manage db sync" manila

echocolor "restart manila service"
service manila-scheduler restart
service manila-api restart

echocolor "Downloading manila image service"
sleep 3

wget http://tarballs.openstack.org/manila-image-elements/images/manila-service-image-master.qcow2

echocolor "Create image manila"
sleep 3 

openstack image create "manila-service-image" \
--file manila-service-image-master.qcow2 \
--disk-format qcow2 \
--container-format bare \
--public

echocolor "create flavor for manila image"
sleep 3
openstack flavor create manila-service-flavor --id 100 --ram 256 --disk 0 --vcpus 1

echocolor "create share-type for manila"
sleep 3
manila type-create default_share_type True



