#!/bin/bash

# Terraform related variables. We are exporting them as environment variables so Terraform can use them in variables.tf.
export TF_VAR_SSHKEY_PATH="/home/user/.ssh"
export TF_VAR_SSHKEY_FILE="lightsail_key"
export TF_VAR_REMOTE_USER="ec2-user"

# Telegram notification related variables.
TELEGRAM_TOKEN=""
TELEGRAM_CHATID=""
TELEGRAM_BOTURL="https://api.telegram.org/bot$TELEGRAM_TOKEN/sendMessage"
# == End of global variables. ==


# Checking network interfaces from deployed instances and taking action based on output of ifconfig command.
networkInterfacesCheck() {
LIST_OF_IPS=$(terraform output -json instance_public_ip | jq '.[]' -r)
LIST_OF_STATES=$(terraform state list | grep "aws_lightsail_instance")

set -- $LIST_OF_IPS
for value in $LIST_OF_STATES; do
    NETWORKINTERFACES=$(ssh -i $TF_VAR_SSHKEY_PATH/$TF_VAR_SSHKEY_FILE $TF_VAR_REMOTE_USER@$1 -o StrictHostKeyChecking=no "ifconfig -l")

    if [ "$NETWORKINTERFACES" = "lo0 xn0" ]; then
        echo "Bad network interface (xn0) on $value ($1)."
    else
        echo "Good network interface (NOT lo0 xn0). Notifying via Telegram"
        # Remove instance from Terraform state list so it does not get destroyed
        terraform state rm $value
        sendTelegramMessage "$value ($1) seems to be a good instance. Please double check."
    fi
    # Changing $1 value to the next in the list
    shift
done
}

# Send messages to Telegram bot.
function sendTelegramMessage() {
# Use "$1" to get the first argument (desired message) passed to this function
# Set parsing mode to HTML because Markdown tags don't play nice in bash script
# Redirect curl output to /dev/null since we don't need to see it (it just replays the message from the bot API)
# Redirect stderr to stdout so we can still see an error message in curl if it occurs
curl -s -X POST $TELEGRAM_BOTURL -d chat_id=$TELEGRAM_CHATID -d text="$1" -d parse_mode="HTML" > /dev/null 2>&1
}

createInstances() {
    terraform apply
}

destroyInstances() {
    terraform destroy
}

## = Script Init =
# Creating instances based on our Terraform configuration files
createInstances

# We verify the network interfaces of the deployed instance, and destroy that instance or notify via Telegram based on th>
networkInterfacesCheck

# Send a message to Telegram to notify the script has finished running
sendTelegramMessage "Lightsail checker has completed its tasks."

# Destroying all instances in the state list
destroyInstances

