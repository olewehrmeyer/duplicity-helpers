#!/bin/bash

set -e

# The folder to go to to run the local backup script. Example here for Paperless NGX
SOFTWARE_FOLDER="/opt/paperless"

B2_KEY_ID="<set your B2 key id here>"
B2_ACCESSKEY="<set your B2 access key here>"
B2_BUCKET="<set your B2 bucket name here>"
B2_KEY="<set your B2 folder here>"

B2_URL=b2://${B2_KEY_ID}:${B2_ACCESSKEY}@${B2_BUCKET}/${B2_KEY}

# this assumes your GPG key has no passphrase
export SIGN_PASSPHRASE=""

# where your local backup script puts the local backup files
BACKUP_SOURCE="/opt/backup/paperless-data"

# GPG key to use for signing and encrypting the backup
# you can find your GPG key with `gpg --list-keys`
GPG_KEY="<set your GPG key here>"

MQTT_SERVER="<set your MQTT server here>"
MQTT_PORT="1883"
MQTT_USER="<set your MQTT user here>"
MQTT_PW="<set your MQTT password here>"
# Display Name and internal name for the HomeAssistant MQTT sensor
MQTT_DISPLAY_NAME="Paperless Backup"
MQTT_NAME="paperless_backup"

perform_local_backup() {
  # An example of a local backup script that exports the data from Paperless NGX
  current_pwd=`pwd`
  cd "$SOFTWARE_FOLDER/src"
  if ! python3 manage.py document_exporter "$BACKUP_SOURCE"; then
    return 1
  fi
  cd "$current_pwd"
}

perform_cloud_backup() {
  duplicity \
    --sign-key $GPG_KEY --encrypt-key $GPG_KEY \
    --full-if-older-than 30D \
    "$BACKUP_SOURCE" \
    "$B2_URL"
  if [ $? -ne 0 ]; then
    return 1
  fi

  duplicity \
    --sign-key $GPG_KEY --encrypt-key $GPG_KEY \
    remove-older-than 90D --force \
    "$B2_URL"
  if [ $? -ne 0 ]; then
    return 1
  fi

  duplicity \
    --sign-key $GPG_KEY --encrypt-key $GPG_KEY \
    cleanup --force \
    "$B2_URL"
  if [ $? -ne 0 ]; then
    return 1
  fi

  duplicity \
    --sign-key $GPG_KEY --encrypt-key $GPG_KEY \
    collection-status \
    "$B2_URL"
  if [ $? -ne 0 ]; then
    return 1
  fi

}

announce_backup_start() {
  mosquitto_pub -h $MQTT_SERVER -p $MQTT_PORT -u $MQTT_USER -P $MQTT_PW -r \
        -t "homeassistant/sensor/$MQTT_NAME/config" \
        -m "{\
            \"name\": \"$MQTT_DISPLAY_NAME\", \
            \"device_class\": \"enum\", \
            \"unique_id\": \"$MQTT_NAME-mqtt\", \
            \"state_topic\": \"homeassistant/sensor/$MQTT_NAME/state\", \
            \"device\": { \"name\": \"$MQTT_DISPLAY_NAME\", \"identifiers\": [ \"$MQTT_NAME\" ] } \
        }"
  mosquitto_pub -h $MQTT_SERVER -p $MQTT_PORT -u $MQTT_USER -P $MQTT_PW \
        -t "homeassistant/sensor/$MQTT_NAME/state" \
        -m 'Running'

}

announce_backup_success() {
  mosquitto_pub -h $MQTT_SERVER -p $MQTT_PORT -u $MQTT_USER -P $MQTT_PW \
        -t "homeassistant/sensor/$MQTT_NAME/state" \
        -m 'Idle'

}

announce_backup_error() {
  mosquitto_pub -h $MQTT_SERVER -p $MQTT_PORT -u $MQTT_USER -P $MQTT_PW \
        -t "homeassistant/sensor/$MQTT_NAME/state" \
        -m 'Error'

}

main() {

  announce_backup_start
  if ! perform_local_backup; then
    announce_backup_error
    exit 1
  fi

  if ! perform_cloud_backup; then
    announce_backup_error
    exit 1
  fi
  announce_backup_success
}

main