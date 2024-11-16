# SMS-to-Discord Integration Documentation

This documentation outlines the process of setting up a custom Docker container that uses Gammu SMSD to receive SMS messages and forward them to a Discord webhook.

---

## Prerequisites

1. **Hardware**: A GSM modem connected to the system via USB.
2. **Host Environment**: A Linux-based system with Docker installed.
3. **Discord Webhook URL**: Obtain from your Discord server settings.

---

## 1. **Prepare the Necessary Files**

### 1.1 `gammu-smsdrc` Configuration
This file configures Gammu SMSD for reading SMS messages from your GSM modem.

```ini
[gammu]
device = /dev/ttyUSB0
connection = at

[smsd]
service = files
logfile = /var/log/gammu-smsd.log
debuglevel = 1
inboxpath = /var/spool/gammu/inbox/
outboxpath = /var/spool/gammu/outbox/
sentboxpath = /var/spool/gammu/sent/
errorpath = /var/spool/gammu/error/
RunOnReceive = /usr/local/bin/send_to_discord.sh
```

---

### 1.2 `send_to_discord.sh` Script
This script processes received SMS messages and sends them to Discord.

```bash
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
```

---

## 2. **Create a Dockerfile**

This Dockerfile builds a custom Docker image with Gammu, SMSD, and the necessary tools.

```Dockerfile
FROM valterseu/gammu-sms:latest

# Install jq for JSON manipulation
RUN apt-get update && apt-get install -y jq

# Copy the Gammu SMSD configuration
COPY gammu-smsdrc /etc/gammu-smsdrc

# Copy the send_to_discord.sh script
COPY send_to_discord.sh /usr/local/bin/send_to_discord.sh

# Ensure the script has execute permissions
RUN chmod +x /usr/local/bin/send_to_discord.sh

# Start gammu-smsd with the configuration
CMD ["gammu-smsd", "-c", "/etc/gammu-smsdrc"]
```

---

## 3. **Build and Run the Docker Container**

### 3.1 Build the Docker Image
Navigate to the directory containing the `Dockerfile` and run:
```bash
docker build -t custom-gammu-sms .
```

### 3.2 Run the Container
Start the container with the necessary device and volume mappings:
```bash
docker run -d \
    --name gammu-sms \
    -v /mnt/user/appdata/gammu-sms-custom/spool:/var/spool/gammu \
    --device=/dev/ttyUSB0 \
    custom-gammu-sms
```

---

## 4. **Test the Setup**

### 4.1 Verify Container Logs
Check the logs to ensure `gammu-smsd` is running and messages are being processed:
```bash
docker logs gammu-sms
```

### 4.2 Test the Script
Manually test the script with a sample SMS file:
```bash
docker exec -it gammu-sms sh
/usr/local/bin/send_to_discord.sh /var/spool/gammu/inbox/example_sms_file.txt
```

### 4.3 Check Debug Logs
Inspect the debug log for any issues:
```bash
docker exec -it gammu-sms sh -c "cat /var/spool/gammu/send_to_discord_debug.log"
```

---

## 5. **Troubleshooting**

- **Error: `jq: not found`**: Ensure `jq` is installed in the container.
- **File Not Found**: Verify the paths in the `RunOnReceive` directive and `send_to_discord.sh`.
- **Invalid JSON Error**: Add debug logging to capture the payload being sent to Discord.

---

## 6. **Maintenance**

To update or restart the container:
1. Stop the current container:
   ```bash
   docker stop gammu-sms
   docker rm gammu-sms
   ```
2. Rebuild the image (if changes were made):
   ```bash
   docker build --no-cache -t custom-gammu-sms .
   ```
3. Start the container again:
   ```bash
   docker run -d \
       --name gammu-sms \
       -v /mnt/user/appdata/gammu-sms-custom/spool:/var/spool/gammu \
       --device=/dev/ttyUSB0 \
       custom-gammu-sms
   ```

---

## 7. **Future Plans**

- Add support for multiple webhooks/ multiple SIMs.
- Implement retries for webhook failures.
- Monitor logs for errors and set up alerting.
