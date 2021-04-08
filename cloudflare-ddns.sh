#/usr/bin/env bash

VERSION="0.1.0"

## Help message
usage() {
  cat <<EOM

USAGE: cloudflare-ddns REQUIRED [OPTIONS]

REQUIRED:
  -z, --zone-id     VALUE   Cloudflare Zone ID
  -t, --auth-token  VALUE   Cloudflare auth token
                            Grab your own from the dashboard
  -n, --record-name VALUE   Record A name to be updated
                            ex: subdomain.example.com
  -i, --record-id   VALUE   Record ID to be updated
                            ex: 6b478246b49546a7b74d954e54bf5b61

OPTIONS:
  -c, --notify-url  VALUE   URL to receive notifications via POST
  -u, --check-ttl   NUMBER  Check interval in seconds
                            default: 30
  -d, --dns-ttl     NUMBER  DNS record TTL in seconds (> 120)
                            default: 120
  -f, --filename    PATH    Filename to record current IP Address
                            default: ~/.cloudflare-ddns/ip-record
  -h, --help                Shows this help page  
  -v, --version             Shows program version      

EOM
}

## Grab values from env-vars
ZONE_ID=$CLOUDFLARE_DDNS_ZONE_ID
AUTH_KEY=$CLOUDFLARE_DDNS_AUTH_TOKEN
A_RECORD_NAME=$CLOUDFLARE_DDNS_RECORD_NAME
A_RECORD_ID=$CLOUDFLARE_DDNS_RECORD_ID
# Interval in seconds
CHECK_INTERVAL=${CLOUDFLARE_DDNS_CHECK_INTERVAL:-30}
# TTL to check for update IP address
TTL_SECONDS=${CLOUDFLARE_DDNS_TTL:-120}
# Place the last recorded public IP address
IP_RECORD=${CLOUDFLARE_DDNS_FILENAME:-~/.cloudflare-ddns/ip-record}
# Email for notifications
NOTIFY_URL=$CLOUDFLARE_DDNS_NOTIFY_URL

## Parse arguments
if [ ! -z $# ]; then
  while (( "$#" )); do
    case "$1" in
      -z|--zone-id)
        if [ -n "$2" ] && [ ${2:0:1} != "-" ]; then
          ZONE_ID=$2
          shift 2
        fi
        ;;
      -t|--auth-token)
        if [ -n "$2" ] && [ ${2:0:1} != "-" ]; then
          AUTH_KEY=$2
          shift 2
        fi
        ;;
      -n|--record-name)
        if [ -n "$2" ] && [ ${2:0:1} != "-" ]; then
          A_RECORD_NAME=$2
          shift 2
        fi
        ;;
      -i|--record-id)
        if [ -n "$2" ] && [ ${2:0:1} != "-" ]; then
          A_RECORD_ID=$2
          shift 2
        fi
        ;;
      -u|--check-ttl)
        if [ -n "$2" ] && [ ${2:0:1} != "-" ]; then
          CHECK_INTERVAL=$2
          shift 2
        fi
        ;;
      -d|--dns-ttl)
        if [ -n "$2" ] && [ ${2:0:1} != "-" ]; then
          TTL_SECONDS=$2
          shift 2
        fi
        ;;
      -f|--filename)
        if [ -n "$2" ] && [ ${2:0:1} != "-" ]; then
          IP_RECORD=$2
          shift 2
        fi
        ;;
      -c|--notify-url)
        if [ -n "$2" ] && [ ${2:0:1} != "-" ]; then
          NOTIFY_URL=$2
          shift 2
        fi
        ;;
      -h|--help)
        echo "Watches for Cloudflare updates on a record"
        usage
        exit 0
        ;;
      -v|--version)
        echo "Version: $VERSION"
        exit 0
        ;;
      -*|--*=)
        echo "Error: Unsupported option $1" >&2
        usage
        exit 1
        ;;
    esac
  done
fi

if [ -z "$ZONE_ID" ]; then
  echo "Error: Argument for -z, --zone-id or CLOUDFLARE_DDNS_ZONE_ID is missing" >&2
  exit 1
fi

if [ -z "$AUTH_KEY" ]; then
  echo "Error: Argument for -t, --auth-token or CLOUDFLARE_DDNS_AUTH_TOKEN is missing" >&2
  exit 1
fi

if [ -z "$A_RECORD_NAME" ]; then
  echo "Error: Argument for -n, --record-name or CLOUDFLARE_DDNS_RECORD_NAME is missing" >&2
  exit 1
fi

if [ -z "$A_RECORD_ID" ]; then
  echo "Error: Argument for -i, --record-id or CLOUDFLARE_DDNS_RECORD_ID is missing" >&2
  exit 1
fi

if [[ -d $IP_RECORD ]]; then
  echo "Error: $IP_RECORD is a directory"
  exit 1
elif [[ -f $IP_RECORD ]]; then
  echo "Warning: $IP_RECORD already exists. Overwriting file."
else
  mkdir -p $(dirname $IP_RECORD)
  touch $IP_RECORD
fi

Run() {
  printf "Checking for IP Address updates... "

  # Fetch the current public IP address
  PUBLIC_IP=$(curl --silent https://api.ipify.org) || return
  RECORDED_IP=`cat $IP_RECORD`

  #If the public ip has not changed, nothing needs to be done, exit.
  if [ "$PUBLIC_IP" = "$RECORDED_IP" ]; then
    echo "IP Address not changed."
    return
  fi

  # Otherwise, your Internet provider changed your public IP... again.
  # Record the new public IP address locally
  echo "IP Address change detected. New IP Addresss: $PUBLIC_IP."
  printf "Updating Cloudflare record... "

  echo $PUBLIC_IP > $IP_RECORD

  # Record the new public IP address on Cloudflare using API v4
  RECORD=$(cat <<EOF
  { "type": "A",
    "name": "$A_RECORD_NAME",
    "content": "$PUBLIC_IP",
    "ttl": $TTL_SECONDS,
    "proxied": false }
EOF
  )

  RESPONSE_STATUS_CODE=$(curl "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records/$A_RECORD_ID" \
    -X PUT \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $AUTH_KEY" \
    -d "$RECORD" \
    -o /dev/null \
    -w '%{http_code}' \
    -s)
  
  if [ "$RESPONSE_STATUS_CODE" -ne 200 ]; then
    echo "Error: status not updated. Cloudflare return $RESPONSE_STATUS_CODE."

    if [ $NOTIFY_URL ]; then
      DATA=$(cat <<EOF
      { "event": "cloudflare_error", 
        "zone_id": "$ZONE_ID", 
        "record_id": "$A_RECORD_ID", 
        "record_name": "$A_RECORD_NAME" }
EOF
      )
      echo "Notifying URL $NOTIFY_URL"
      curl -X POST $NOTIFY_URL \
        -A "CloudflareDDNS/$VERSION" \
        -d "$DATA" \
        -o /dev/null \
        -w '%{http_code}' \
        -s
    fi
  else
    echo "Updated."
  fi
}

cat <<EOM
Starting Cloudflare DDNS daemon 
  Check TTL: $CHECK_INTERVAL seconds
   Record A: $A_RECORD_NAME
    Zone ID: $ZONE_ID
    DNS TTL: $TTL_SECONDS seconds

Running in watch mode..
EOM

while true
do
  Run
  sleep $CHECK_INTERVAL
done
