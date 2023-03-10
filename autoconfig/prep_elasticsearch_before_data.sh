#!/bin/bash
#
# Author:	 Jason Barnett <xasmodeanx@gmail.com>
# Maintainer: Brett Kuskie <fullaxx@gmail.com>
#
# This script preps the elasticsearch/kibana server to begin receiving data.
# We have to create our initial indices and start building mappings and kibana index patterns
# before we start generating data and uploading it through the bulk api

INDICES="packets"
ELASTICSERVER="localhost"
PASSWORDFILE="/data/passwords"
JSONDIR="/elasticsearch/autoconfig/"

# Before we fire off all of these configs, we need to give elasticsearch and kibana a chance
# to properly start up all the way. If Kibana is healthy, then we know elasticsearch is also healthy
# so we only need to check Kibana's status
echo "$0 started by `whoami` on `date`"

# We need to wait for elasticsearch to come up before proceeding
ELASTICSEARCHEALTH="`curl -sS http://${ELASTICSERVER}:9200/_cat/health`"
ELASTICSEARCHHEALTHSTATUS="$?"
while [ "${ELASTICSEARCHHEALTHSTATUS}" -ne "0" ]; do
	echo "Elasticsearch was not ready. Curl reports: ${ELASTICSEARCHHEALTHSTATUS}: ${ELASTICSEARCHEALTH}"
	sleep 2
	ELASTICSEARCHEALTH="`curl -sS http://${ELASTICSERVER}:9200/_cat/health`"
	ELASTICSEARCHHEALTHSTATUS="$?"
done
sleep 1
echo

# We need to ensure that the security for elasticsearch has been set up properly before moving on
# If this is the first time the container has ever been started and this script run, we need to do some work...
if ! [ -e "/.firstrun" ]; then
	echo "Adding password to Elasticsearch/kibana to secure it"
	echo "y" | /usr/share/elasticsearch/bin/elasticsearch-setup-passwords auto >${PASSWORDFILE}
	# Let's make sure folks can not read our password file...
	chmod o-rwx ${PASSWORDFILE}
#	cp -fv ${PASSWORDFILE} /etc/elasticsearch/
#	ln -s ${PASSWORDFILE} /elasticsearch/autoconfig/
	KIBANA_SYSTEM_PASSWORD="`cat ${PASSWORDFILE} | grep 'PASSWORD kibana_system' | awk '{print $4}'`"
	ELASTIC_PASSWORD="`cat ${PASSWORDFILE} | grep 'PASSWORD elastic = ' | awk '{print $4}'`"
	echo "KIBANA_SYSTEM_PASSWORD was: ${KIBANA_SYSTEM_PASSWORD}"
	rm -f /etc/kibana/kibana.keystore
	/usr/share/kibana/bin/kibana-keystore create
	echo "Adding kibana_system password to kibana keystore"
	echo "${KIBANA_SYSTEM_PASSWORD}" | /usr/share/kibana/bin/kibana-keystore add elasticsearch.password
	ln -s /usr/share/kibana/config/kibana.keystore /etc/kibana/
	ln -sf /usr/share/kibana/config/kibana.yml /etc/kibana/kibana.yml
	# We need to throw the elasticsearch kibana_system password into the kibana config. If this field already exists, update it to what it should be
	if [ "`cat /etc/kibana/kibana.yml | grep elasticsearch.password`" ]; then
		sed -ci "/elasticsearch.password/c\elasticsearch.password: \"${KIBANA_SYSTEM_PASSWORD}\"" /usr/share/kibana/config/kibana.yml
	else
		echo "elasticsearch.password: \"${KIBANA_SYSTEM_PASSWORD}\"" >> /usr/share/kibana/config/kibana.yml
	fi
	# Restart kibana to pick up the new password
	supervisorctl restart kibana
else
	# Enumerate our passwords
	KIBANA_SYSTEM_PASSWORD="`cat ${PASSWORDFILE} | grep 'PASSWORD kibana_system' | awk '{print $4}'`"
	ELASTIC_PASSWORD="`cat ${PASSWORDFILE} | grep 'PASSWORD elastic = ' | awk '{print $4}'`"
fi

KIBANAHEALTH="`curl -sS -XGET ${ELASTICSERVER}:5601 2>&1`"
#echo "KIBANAHEALTH was ${KIBANAHEALTH}"
while ! [ -z "${KIBANAHEALTH}" ]; do
	echo "Kibana was not ready. Curl reports: ${KIBANAHEALTH}"
	sleep 2
	KIBANAHEALTH="`curl -sS -XGET ${ELASTICSERVER}:5601 2>&1`"
done
sleep 1
echo

echo "Elasticsearch and Kibana are ready to receive configurations and data now."
cd "${JSONDIR}"

################################################################################
# Create Lifecycle policies for index data									 #
################################################################################
# We have to set some hard limits as to how much data in days we want 
# to keep for each index.  For this project, keep up to 365 days.
for index in ${INDICES}; do
	# If we have a characterization mapping json object in this folder with the proper index identified, execute it against the index
	if [ -e "${index}-lifecycle-policy.json" ]; then
		echo "Attempting to create lifecycle policy for index: ${index}"
		curl -u elastic:${ELASTIC_PASSWORD} -X PUT "${ELASTICSERVER}:9200/_ilm/policy/${index}-lifecycle-policy?pretty" -H 'Content-Type: application/json' -d@${index}-lifecycle-policy.json
	fi
done
sleep 1
echo

################################################################################
# Create Index templates, with lifecycle policies by default				   #
################################################################################
for index in ${INDICES}; do
	# If we have a index template json object in this folder with the proper index identified, execute it against the index
	if [ -e "${index}-index-template.json" ]; then
		echo "Attempting to create index template for index: ${index}"		
		curl -u elastic:${ELASTIC_PASSWORD} -X PUT "${ELASTICSERVER}:9200/_template/${index}-index-template?pretty" -H 'Content-Type: application/json' -d@${index}-index-template.json
	fi
done
sleep 1
echo

################################################################################
# Create the necessary empty indices in elasticsearch, forcing lifecycle	   #
################################################################################
for index in ${INDICES}; do
	echo "Attempting to create index: ${index}"
	if [[ -e "${index}-lifecycle-policy.json" && -e "${index}-blank-index-with-lifecycle.json" ]]; then
		echo "index: ${index} will have lifecycle policy ${index}-lifecycle-policy by default"
		# We have a defined lifecycle policy and we should create the index to adhere to it
		curl -u elastic:${ELASTIC_PASSWORD} -X PUT "${ELASTICSERVER}:9200/${index}-000001?pretty" -H 'Content-Type: application/json' -d@${index}-blank-index-with-lifecycle.json
	else
		# No lifecycle policy should apply, let it rip
		echo "index: ${index} will not have a default lifecycle policy because there was no lifecycle defined for this index or a policy was specified but no matching index creation template existed."
		curl -u elastic:${ELASTIC_PASSWORD} -X PUT "${ELASTICSERVER}:9200/${index}-000001?pretty"
	fi
done
sleep 1
echo

################################################################################
# Create Kibana Discover Boards and Index-patterns							 #
################################################################################
#We have to create some integration with the data into Kibana so that
#you can have a nice, easy-to-use UI to search through the data
#at http://${ELASTICSERVER}:5601/app/discover
for index in ${INDICES}; do
	# If we have a packet mapping json object in this folder with the proper index identified, execute it against the index
	if [ -r "${index}-kibana-index-pattern.json" ]; then
		echo "Attempting to create a Kibana Discover board and Index-pattern for index: ${index}"
		curl -u elastic:${ELASTIC_PASSWORD} -X POST "http://${ELASTICSERVER}:5601/api/saved_objects/index-pattern/${index}" -H 'kbn-xsrf: true' -H 'Content-Type: application/json' -d@${index}-kibana-index-pattern.json
	fi
done
sleep 1
echo

################################################################################
# Create a restricted user role and add a user to it						   #
################################################################################
echo "Creating User accounts and roles ..."
for ROLE in accounts/*.role.json; do
  ROLENAME=`basename ${ROLE} | cut -f1 -d.`
  URL="http://${ELASTICSERVER}:5601/api/security/role/${ROLENAME}"
  echo "PUTting ${ROLE} to ${URL} ..."
  curl -u elastic:${ELASTIC_PASSWORD} -X PUT ${URL} -H 'kbn-xsrf: true' -H 'Content-Type: application/json' -d@${ROLE}
done
for USER in accounts/*.user.json; do
  USERNAME=`basename ${ROLE} | cut -f1 -d.`
  URL="http://${ELASTICSERVER}:9200/_security/user/${USERNAME}?pretty"
  echo "PUTting ${USER} to ${URL} ..."
  curl -u elastic:${ELASTIC_PASSWORD} -X PUT "${URL}" -H 'Content-Type: application/json' -d@${USER}
done
echo

################################################################################
# Enable Kibana/Elasticsearch anonymous access and serve out on /kibana		#
################################################################################
# We change kibana.yml here so that Kibana no longer asks for a user
# or password, an instead logs in with the anonymous user created above
# with the default password of anonymous.  This user has a very specific
# role defined which provides READ-ONLY access to Pakcet indexes: packets
# NOTE: If you need to get the login page back, like to enter your admin username/password to alter Kibana configs,
# uncomment the lines in kibana.yml below that we are commenting out and then restart the container or kibana processes.
if ! [ -e "/.firstrun" ]; then
	# Allow Anonymous logins on Kibana and serve Kibana on /kibana
	sed -e "s|#server.basePath: \"/kibana\"|server.basePath: \"/kibana\"|g" -e "s|#server.rewriteBasePath: \"true\"|server.rewriteBasePath: \"true\"|g" /usr/share/kibana/config/kibana.yml > /usr/share/kibana/config/kibana.yml.autologin
	cp -fv /usr/share/kibana/config/kibana.yml.autologin /usr/share/kibana/config/kibana.yml
	rm -f /usr/share/kibana/config/kibana.yml.autologin

	# Allow Anonymous read-only access to elasticsearch indices and API
	sed -e "s|#xpack.security.authc:|xpack.security.authc:|g" -e "s|#anonymous:|anonymous:|g" -e "s|#roles: anonymous|roles: anonymous|g" /usr/share/elasticsearch/config/elasticsearch.yml > /usr/share/elasticsearch/config/elasticsearch.yml.autologin
	cp -fv /usr/share/elasticsearch/config/elasticsearch.yml.autologin /usr/share/elasticsearch/config/elasticsearch.yml
	rm -f /usr/share/elasticsearch/config/elasticsearch.yml.autologin

	# Restart elasticsearch to pick up the new anonymous access directives
	supervisorctl restart elasticsearch
	sleep 5
	# Restart kibana to pick up the new password
	supervisorctl restart kibana
fi
touch /.firstrun

echo "$0 done at `date`"
exit 0
