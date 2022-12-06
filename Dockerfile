FROM ubuntu:20.04

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update
RUN apt-get -y install git awscli dnsutils curl

WORKDIR /app

RUN git clone https://github.com/famzah/aws-dyndns.git
RUN chmod +x aws-dyndns/aws-dyndns

COPY ./bootstrap.sh /app
RUN chmod 755 bootstrap.sh
CMD ["/app/bootstrap.sh"]