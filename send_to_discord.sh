#!/bin/bash

file="$1"

if [ ! -f "$file" ]; then
    echo "File $file not found!"
    exit 1
fi

# Extract the sender and message
SENDER=$(grep "^From:" "$file" | cut -d: -f2 | xargs)
MESSAGE=$(grep "^Text:" "$file" | cut -d: -f2- | xargs)

if [ -z "$SENDER" ]; then
    SENDER="Unknown Sender"
fi

if [ -z "$MESSAGE" ]; then
    MESSAGE="No message content."
fi

# Prepare the payload
PAYLOAD=$(jq -n \
    --arg sender "$SENDER" \
    --arg message "$MESSAGE" \
    '{content: "New SMS from: \($sender)\nMessage: \($message)"}')

# Send to Discord
WEBHOOK_URL="https://discord.com/api/webhooks/YOUR_WEBHOOK_URL"
curl -X POST -H "Content-Type: application/json" -d "$PAYLOAD" "$WEBHOOK_URL"

# Log for debugging
echo "Sender: $SENDER" >> /var/spool/gammu/send_to_discord_debug.log
echo "Text: $MESSAGE" >> /var/spool/gammu/send_to_discord_debug.log
echo "Payload: $PAYLOAD" >> /var/spool/gammu/send_to_discord_debug.log
