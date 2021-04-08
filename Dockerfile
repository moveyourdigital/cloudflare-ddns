FROM bash
RUN set -eux; \
	  \
	  apk add --no-cache \
      curl \
    ;

COPY ./cloudflare-ddns.sh /usr/local/bin/cloudflare-ddns
RUN chmod +x /usr/local/bin/cloudflare-ddns

CMD ["cloudflare-ddns"]