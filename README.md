
# meta-mend

A Layer to support Mend SCA (Software Composition Analysis) for open-source vulnerabilities in Yocto.


## usage

This layer exposes a bbclass to apply mend checking.
It uses the `mend-cli` standalone tool provided by Mend.
To automatically authenticate the `mend-cli` tool and allow it to
access your organisation, some environment variables must be
exported:

    MEND_URL
    MEND_USER_KEY
    MEND_EMAIL
For this project, the variables are exported directly from the
`.bbclass`, so it is sufficient to add them as follows:

 ### In conf/local.conf (or in the local_conf_header section of the kas configuration):
    INHERIT += " mend"
    
    WS_USERKEY = "<userKey>"
    WS_APIKEY = "<apiKey>"
    WS_WSS_URL = "<wssUrl>"
    WS_PRODUCTNAME = "<productName>"
    WS_PRODUCTTOKEN = "<productToken>"
    MEND_URL = "<wssUrl>"
    MEND_USER_KEY = "<userKey>"
    MEND_EMAIL = "<email>"
