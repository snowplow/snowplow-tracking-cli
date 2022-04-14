FROM alpine:3.14
MAINTAINER TechOps "support@snowplowanalytics.com"

ADD build/output/linux/snowplow-tracking-cli /root/

ENTRYPOINT ["/root/snowplow-tracking-cli"]
