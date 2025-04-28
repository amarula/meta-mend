FROM ghcr.io/siemens/kas/kas:4.7
ARG DEBIAN_FRONTEND=noninteractive

RUN sudo apt-get update
RUN sudo apt-get install -y \
            openjdk-17-jre \
            openjdk-17-jdk; \
            sudo apt-get clean;

RUN mkdir -p /builder && wget https://unified-agent.s3.amazonaws.com/wss-unified-agent.jar -P /builder

COPY amarula.wss.config /builder
