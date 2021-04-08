# Cloudflare DDNS daemon

Daemon that listens for public IP address changes and updates a 
record in Cloudflare accordingly.

## Usage 

We have two methods available.

### Docker

Create a `.env` file with:
```
CLOUDFLARE_DDNS_ZONE_ID=
CLOUDFLARE_DDNS_AUTH_TOKEN=
CLOUDFLARE_DDNS_RECORD_NAME=
CLOUDFLARE_DDNS_RECORD_ID=
```

And run:
```
docker run --restart always --env-file .env -it moveyourdigital/cloudflare-ddns:latest
```

### Standalone
```
./cloudflare-ddns.sh \
  --zone-id <cf-zone-id> \
  --auth-token <cf-auth-token> \
  --record-name <cf-record-name> \
  --record-id <cf-record-id>
```

### Options
```
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
                            default: 60
  -d, --dns-ttl     NUMBER  DNS record TTL in seconds (> 120)
                            default: 120
  -f, --filename    PATH    Filename to record current IP Address
                            default: ~/.cloudflare-ddns/ip-record
  -h, --help                Shows this help page  
  -v, --version             Shows program version      
```
