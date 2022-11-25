#!/bin/bash

# == Global variables. ==
# Lightsail related variables.
PROFILE=""
OPERATING_SYSTEM="freebsd_12"
INSTANCE_TYPE="nano_2_0" # 3.5 USD
# INSTANCE_TYPE="micro_2_0" # 5 USD
# INSTANCE_TYPE="small_2_0" # 10 USD

# Telegram notification related variables.
telegram_token=""
telegram_chatid=""
telegram_boturl="https://api.telegram.org/bot$telegram_token/sendMessage"
# == End of global variables. ==

# Obtaining list of Lightsail regions.
obtainLightsailRegions() {
REGIONS=$(aws lightsail get-regions \
--query 'regions[].[displayName,name]' \
--profile=$PROFILE \
--output=text)

echo "Available regions in Lightsail:"
echo "==="
echo "$REGIONS"
echo "== End of list =="
echo ""

echo "Please enter the desired region in AWS format (example: us-east-2): "
read INPUT_REGION
echo ""
}

# Obtaining list of availability zones within the selected Lightsail region.
obtainLightsailRegionAvailabilityZones() {
echo "Loading availability zone list for selected region..."
AZS=$(aws lightsail get-regions \
--query 'regions[].availabilityZones[].zoneName' \
--include-availability-zones \
--region $INPUT_REGION \
--profile=$PROFILE \
--output=json | jq '.[]' -r)

echo "There are $(wc -l <<< $AZS) availability zones in this region."
echo ""
echo "An instance will be deployed in each availability region, which may incur in significant costs. Please remember that Lightsail charges on an hourly basis. Press Enter key to continue, or CTRL+C to abort."
read CONFIRMATION
}

# Creating instances in each availability zone of selected Lightsail region.
createInstance() {
for value in $AZS; do
    aws lightsail create-instances \
    --instance-names "checker_$value" \
    --region "$INPUT_REGION" \
    --availability-zone "$value" \
    --blueprint-id "$OPERATING_SYSTEM" \
    --bundle-id "$INSTANCE_TYPE" \
    --tags "key=instance_type,value=checker" \
    --profile=$PROFILE
done
}

# Downloading default Lightsail SSH key for the selected region and setting correct permissions.
# Note: The SSH key will be downloaded in the same folder where this script resides.
downloadDefaultSSHKey() {
aws lightsail download-default-key-pair \
--query 'privateKeyBase64' \
--profile=$PROFILE \
--region $INPUT_REGION \
--output=text > default_lightsail_key_${INPUT_REGION}.pem

# Modifying permissions of downloaded file to prevent permission misconfiguration error when attempting to use the key.
chmod 600 default_lightsail_key_${INPUT_REGION}.pem
}

# Obtaining public IPs of created instances in the specific region, using tags.
obtainPublicIP() {
IPADDRESSES=$(aws lightsail get-instances \
--region $INPUT_REGION \
--query 'instances[?tags[?value==`checker`]].publicIpAddress' \
--profile=$PROFILE \
--output=json | jq '.[]' -r)
}

# Checking network interfaces from deployed instances and taking action based on output of ifconfig command.
networkInterfacesCheck() {
for value in $IPADDRESSES; do
    NETWORKINTERFACES=$(ssh -i default_lightsail_key_${INPUT_REGION}.pem ec2-user@$value -o StrictHostKeyChecking=no "ifconfig -l")

    if [ "$NETWORKINTERFACES" = "lo0 xn0" ]; then
        echo "Bad network interface (xn0) on $value. Destroying instance"
        # Obtaining instance name based on the public IP address.
        INSTANCE_NAME=$(aws lightsail get-instances \
        --region $INPUT_REGION \
        --query "instances[?publicIpAddress==\`$value\`].name" \
        --profile=$PROFILE \
        --output=text)

        # Destroying undesired instance.
        aws lightsail delete-instance \
        --instance-name $INSTANCE_NAME \
        --region $INPUT_REGION \
        --profile=$PROFILE
    else
        echo "Good network interface (NOT lo0 xn0). Notifying via Telegram"
        sendTelegramMessage "$value seems to be a good instance. Please double check."
    fi
done
}

# Send messages to Telegram bot.
sendTelegramMessage() {
# Use "$1" to get the first argument (desired message) passed to this function
# Set parsing mode to HTML because Markdown tags don't play nice in bash script
# Redirect curl output to /dev/null since we don't need to see it (it just replays the message from the bot API)
# Redirect stderr to stdout so we can still see an error message in curl if it occurs
curl -s -X POST $telegram_boturl -d chat_id=$telegram_chatid -d text="$1" -d parse_mode="HTML" > /dev/null 2>&1
}


# == Script init ==
# Fetching all available regions where Lightsail is available.
obtainLightsailRegions

# Fetching all availability zones inside of the selected region. We want to deploy an instance in each availability zone.
obtainLightsailRegionAvailabilityZones $INPUT_REGION

# Downloading default Lightsail SSH key for the selected region.
downloadDefaultSSHKey

# Creating the relevant amount of instances inside of the selected region, one instance per availability zone.
# Beware: These instances will be configured with open 22/TCP and 80/TCP ports to everyone.
# Default SSH key for the Lightsail region is used.
createInstance

# SSH availability after instance deployment could take up to 10 minutes, therefore the allow some time before attempting SSH access.
echo "Waiting for 600 seconds before attempting to connect via SSH... You will be notified via Telegram once this process finishes."
sleep 600

# Once the instance is deployed, we need to obtain its public IP address, in order to be able to SSH in.
obtainPublicIP

# We verify the network interfaces of the deployed instance, and destroy that instance or notify via Telegram based on the desired values.
networkInterfacesCheck

# Send a message to Telegram to notify the script has finished running
sendTelegramMessage "Lightsail checker has completed its tasks for $INPUT_REGION."
