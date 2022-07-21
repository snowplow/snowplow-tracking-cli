FROM alpine:3.14
MAINTAINER TechOps "support@snowplowanalytics.com"

ADD build/output/linux/amd64/snowplow-tracking-cli /root/

ENTRYPOINT ["/root/snowplow-tracking-cli"]
