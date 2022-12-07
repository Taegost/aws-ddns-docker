FROM phusion/baseimage:jammy-1.0.1

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update
RUN apt-get -y install git awscli dnsutils curl

RUN mkdir /etc/service/ddns
COPY ./bootstrap.sh /etc/service/ddns/run
RUN chmod 755 /etc/service/ddns/run
