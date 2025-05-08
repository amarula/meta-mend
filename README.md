
# meta-mend

A Layer to support Mend SCA (Software Composition Analysis) for open-source vulnerabilities in Yocto.


## usage

This layer exposes a bbclass to apply mend checking.
It requires the host's java runtime, for which a custom `kas-container` image is provided, which also includes Java.

 ### In conf/local.conf (or in the local_conf_header section of the kas configuration):
    INHERIT += " mend"
    
    WS_USERKEY = "<userKey>"
    WS_APIKEY = "<apiKey>"
    WS_WSS_URL = "<wssUrl>"
    WS_PRODUCTNAME = "<productName>"
    WS_PRODUCTTOKEN = "<productToken>"


If using kas-container, `docker load` the docker image container found at:
https://drive.google.com/file/d/1gMtveXMFtlW_pdADBy5-ARqEu4dgyN7p
then prepend the following to the command when using kas-container:
    KAS_CONTAINER_IMAGE=amarula/kas-java:latest kas-container [...]

Alternative you can use docker-compose. Adjust your docker registry to
your specific one and KAS_CONTAINER_IMAGE to the right one.

    cd docker
    docker compose build
