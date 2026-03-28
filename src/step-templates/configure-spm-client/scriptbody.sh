APP_GUID="#{appguid}"
APP_TYPE="#{applicationtype}"
APP_MODE="#{applicationmode}"
JMXADDR="#{jmxhostaddress}"
JMXPORT="#{jmxhostport}"

echo sudo bash /opt/spm/bin/spm-client-setup-conf.sh ${APP_GUID} ${APP_TYPE} ${APP_MODE} jmxhost:${JMXADDR} jmxport:${JMXPORT}
sudo bash /opt/spm/bin/spm-client-setup-conf.sh ${APP_GUID} ${APP_TYPE} ${APP_MODE} jmxhost:${JMXADDR} jmxport:${JMXPORT}
sudo service spm-monitor restart