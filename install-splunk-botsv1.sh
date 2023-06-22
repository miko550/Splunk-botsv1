#! /bin/bash
# Adopted from the great DetectionLab
# This will install Splunk + BOTSv1 Attack only dataset

if [ "$EUID" -ne 0 ]; then 
  echo "Please run as root"
  exit 1
fi

install_splunk() {
  # Check if Splunk is already installed
  if [ -f "/opt/splunk/bin/splunk" ]; then
      echo "[$(date +%H:%M:%S)]: Splunk is already installed"
  else
      echo "[$(date +%H:%M:%S)]: Installing Splunk..."
      # Get download.splunk.com into the DNS cache. Sometimes resolution randomly fails during wget below
      dig @8.8.8.8 download.splunk.com >/dev/null
      dig @8.8.8.8 splunk.com >/dev/null
      dig @8.8.8.8 www.splunk.com >/dev/null

  # Try to resolve the latest version of Splunk by parsing the HTML on the downloads page
  echo "[$(date +%H:%M:%S)]: Attempting to autoresolve the latest version of Splunk..."
  LATEST_SPLUNK=$(curl https://www.splunk.com/en_us/download/splunk-enterprise.html | grep -i deb | grep -Eo "data-link=\"................................................................................................................................" | cut -d '"' -f 2)
  # Sanity check what was returned from the auto-parse attempt
  if [[ "$(echo $LATEST_SPLUNK | grep -c "^https:")" -eq 1 ]] && [[ "$(echo $LATEST_SPLUNK | grep -c "\.deb$")" -eq 1 ]]; then
      echo "[$(date +%H:%M:%S)]: The URL to the latest Splunk version was automatically resolved as: $LATEST_SPLUNK"
      echo "[$(date +%H:%M:%S)]: Attempting to download..."
      wget --progress=bar:force -P /opt "$LATEST_SPLUNK"
  else
      echo "[$(date +%H:%M:%S)]: Unable to auto-resolve the latest Splunk version. Falling back to hardcoded URL..."

      # Download Hardcoded Splunk
      # splunk 9.0.4.1
      wget --progress=bar:force -O /opt/splunk-9.0.4.1.deb 'https://download.splunk.com/products/splunk/releases/9.0.4.1/linux/splunk-9.0.4.1-419ad9369127-linux-2.6-amd64.deb&wget=true'
      # splunk 8.2.9
      # wget --progress=bar:force -O /opt/splunk-8.2.9.deb 'https://download.splunk.com/products/splunk/releases/8.2.9/linux/splunk-8.2.9-4a20fb65aa78-linux-2.6-amd64.deb&wget=true'
      # splunk 7.1.9
      # wget --progress=bar:force -O /opt/splunk-7.1.9.deb 'https://download.splunk.com/products/splunk/releases/7.1.9/linux/splunk-7.1.9-45b25e1f9be3-linux-2.6-amd64.deb&wget=true'
  fi
  # Setup splunk
  dpkg -i /opt/splunk*.deb
  /opt/splunk/bin/splunk start --accept-license --answer-yes --no-prompt --seed-passwd changeme

  # Install add-ins/apps
  /opt/splunk/bin/splunk install app apps/fortinet-fortigate-add-on-for-splunk_167.tgz -auth 'admin:changeme'
  /opt/splunk/bin/splunk install app apps/splunk-add-on-for-microsoft-sysmon_1062.tgz -auth 'admin:changeme'
  /opt/splunk/bin/splunk install app apps/splunk-add-on-for-microsoft-windows_870.tgz -auth 'admin:changeme'
  /opt/splunk/bin/splunk install app apps/splunk-app-for-stream_811.tgz -auth 'admin:changeme'
  /opt/splunk/bin/splunk install app apps/splunk-ta-for-suricata_233.tgz -auth 'admin:changeme'
  /opt/splunk/bin/splunk install app apps/tenable-add-on-for-splunk_614.tgz  -auth 'admin:changeme'
  /opt/splunk/bin/splunk install app apps/url-toolbox_192.tgz -auth 'admin:changeme'
  /opt/splunk/bin/splunk install app apps/boss-of-the-soc-bots-investigation-workshop-for-splunk_122.tgz  -auth 'admin:changeme'

  # Install BOTSv1 dataset
  echo "[$(date +%H:%M:%S)]: Downloading Splunk BOTSv1 Attack Only Dataset..."
  wget --progress=bar:force -P /opt/ https://s3.amazonaws.com/botsdataset/botsv1/botsv1-attack-only.tgz
  echo "[$(date +%H:%M:%S)]: Download Complete."
  echo "[$(date +%H:%M:%S)]: Extracting to Splunk Apps directory"
  tar zxvf /opt/botsv1-attack-only.tgz -C /opt/splunk/etc/apps/

  # Add a Splunk TCP input on port 9997
  echo -e "[splunktcp://9997]\nconnection_host = ip" >/opt/splunk/etc/apps/search/local/inputs.conf
 
  # Bump the memtable limits to allow for the ASN lookup table
   cp /opt/splunk/etc/system/default/limits.conf /opt/splunk/etc/system/local/limits.conf
  sed -i.bak 's/max_memtable_bytes = 10000000/max_memtable_bytes = 30000000/g' /opt/splunk/etc/system/local/limits.conf

  # Skip Splunk Tour and Change Password Dialog
  echo "[$(date +%H:%M:%S)]: Disabling the Splunk tour prompt..."
  touch /opt/splunk/etc/.ui_login
  mkdir -p /opt/splunk/etc/users/admin/search/local
  echo -e "[search-tour]\nviewed = 1" >/opt/splunk/etc/system/local/ui-tour.conf
  # Source: https://answers.splunk.com/answers/660728/how-to-disable-the-modal-pop-up-help-us-to-improve.html
  
  echo '[general]
    render_version_messages = 0
    hideInstrumentationOptInModal = 1
    dismissedInstrumentationOptInVersion = 1
    [general_default]
    hideInstrumentationOptInModal = 1
    showWhatsNew = 0
    notification_python_3_impact = false' >/opt/splunk/etc/system/local/user-prefs.conf
  echo '[general]
    render_version_messages = 0
    hideInstrumentationOptInModal = 1
    dismissedInstrumentationOptInVersion = 1
    [general_default]
    hideInstrumentationOptInModal = 1
    showWhatsNew = 0
    notification_python_3_impact = false' >/opt/splunk/etc/apps/user-prefs/local/user-prefs.conf
  # Disable the instrumentation popup
  echo -e "showOptInModal = 0\noptInVersionAcknowledged = 4" >>/opt/splunk/etc/apps/splunk_instrumentation/local/telemetry.conf

  # Enable SSL Login for Splunk
  echo -e "[settings]\nenableSplunkWebSSL = true" >/opt/splunk/etc/system/local/web.conf
  # Reboot Splunk to make changes take effect
  /opt/splunk/bin/splunk restart
  /opt/splunk/bin/splunk enable boot-start
  # Generate the ASN lookup table
  /opt/splunk/bin/splunk search "|asngen | outputlookup asn" -auth 'admin:changeme'
}

main() {
  install_splunk
  echo "BOTSv1 Installation complete!"
}

main
exit 0
