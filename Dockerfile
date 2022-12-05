FROM ubuntu:20.04

# Initial setup
ENV DEBIAN_FRONTEND=noninteractive
WORKDIR ~
RUN apt-get update
RUN apt-get -y install git awscli dnsutils curl

RUN git clone https://github.com/famzah/aws-dyndns.git
RUN chmod +x aws-dyndns/aws-dyndns