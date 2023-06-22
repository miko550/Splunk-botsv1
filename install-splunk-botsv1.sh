#! /bin/bash
# Adopted from the great DetectionLab
# This will install Splunk + BOTSv1 Attack only dataset

if [ "$EUID" -ne 0 ]; then 
  echo "Please run as root"
  exit 1
fi

install_splunk() {
  # Download Hardcoded Splunk
  # splunk 9.0.4.1
  wget --progress=bar:force -O /opt/splunk-9.0.4.1.deb 'https://download.splunk.com/products/splunk/releases/9.0.4.1/linux/splunk-9.0.4.1-419ad9369127-linux-2.6-amd64.deb'
  # splunk 8.2.9
  # wget --progress=bar:force -O /opt/splunk-8.2.9.deb 'https://download.splunk.com/products/splunk/releases/8.2.9/linux/splunk-8.2.9-4a20fb65aa78-linux-2.6-amd64.deb'
  # splunk 7.1.9
  # wget --progress=bar:force -O /opt/splunk-7.1.9.deb 'https://download.splunk.com/products/splunk/releases/7.1.9/linux/splunk-7.1.9-45b25e1f9be3-linux-2.6-amd64.deb'
  
  # Setup splunk
  dpkg -i /opt/splunk*.deb
  /opt/splunk/bin/splunk start --accept-license --answer-yes --no-prompt --seed-passwd splunkadmin

  # Install add-ins/apps
  wget --no-check-certificate 'https://docs.google.com/uc?export=download&id=1cxOS7swv4uB4RogkzNaO2tj5RYyTshIT' -O apps/splunk-app-for-stream_811.tgz

  /opt/splunk/bin/splunk install app apps/fortinet-fortigate-add-on-for-splunk_167.tgz -auth 'admin:splunkadmin'
  /opt/splunk/bin/splunk install app apps/splunk-add-on-for-microsoft-sysmon_1062.tgz -auth 'admin:splunkadmin'
  /opt/splunk/bin/splunk install app apps/splunk-add-on-for-microsoft-windows_870.tgz -auth 'admin:splunkadmin'
  /opt/splunk/bin/splunk install app apps/splunk-app-for-stream_811.tgz -auth 'admin:splunkadmin'
  /opt/splunk/bin/splunk install app apps/splunk-ta-for-suricata_233.tgz -auth 'admin:splunkadmin'
  /opt/splunk/bin/splunk install app apps/tenable-add-on-for-splunk_614.tgz -auth 'admin:splunkadmin'
  /opt/splunk/bin/splunk install app apps/url-toolbox_192.tgz -auth 'admin:splunkadmin'
  /opt/splunk/bin/splunk install app apps/boss-of-the-soc-bots-investigation-workshop-for-splunk_122.tgz  -auth 'admin:splunkadmin'

  # Install BOTSv1 dataset
  echo "[$(date +%H:%M:%S)]: Downloading Splunk BOTSv1 Attack Only Dataset..."
  wget --progress=bar:force -P /opt/ https://s3.amazonaws.com/botsdataset/botsv1/botsv1-attack-only.tgz
  echo "[$(date +%H:%M:%S)]: Download Complete."
  echo "[$(date +%H:%M:%S)]: Extracting to Splunk Apps directory"
  tar zxvf /opt/botsv1-attack-only.tgz -C /opt/splunk/etc/apps/

  # Skip Splunk Tour and Change Password Dialog
  echo "[$(date +%H:%M:%S)]: Disabling the Splunk tour prompt..."
  touch /opt/splunk/etc/.ui_login
  mkdir -p /opt/splunk/etc/users/admin/search/local
  echo -e "[search-tour]\nviewed = 1" >/opt/splunk/etc/system/local/ui-tour.conf
  # Source: https://answers.splunk.com/answers/660728/how-to-disable-the-modal-pop-up-help-us-to-improve.html
  
  # Disable the instrumentation popup
  echo -e "showOptInModal = 0\noptInVersionAcknowledged = 4" >>/opt/splunk/etc/apps/splunk_instrumentation/local/telemetry.conf

  # Enable SSL Login for Splunk
  echo -e "[settings]\nenableSplunkWebSSL = true" >/opt/splunk/etc/system/local/web.conf
  # Reboot Splunk to make changes take effect
  /opt/splunk/bin/splunk restart
  /opt/splunk/bin/splunk enable boot-start
  # Generate the ASN lookup table
  /opt/splunk/bin/splunk search "|asngen | outputlookup asn" -auth 'admin:splunkadmin'

  #clean up
  rm /opt/splunk*.deb
  rm /opt/botsv1-attack-only.tgz
}

main() {
  install_splunk
  echo "[$(date +%H:%M:%S)]: BOTSv1 Installation complete!"
}

main
exit 0
