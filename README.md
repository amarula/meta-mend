
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

```
    INHERIT += " mend"
    
    WS_USERKEY = "<userKey>"
    WS_APIKEY = "<apiKey>"
    WS_PRODUCTNAME = "<productName>"
    MEND_URL = "<mendUrl>"
    MEND_EMAIL = "<email>"
```

- `INHERIT += " mend"` is similar to what is done for _cve_ checking,
  and makes it so that all recipes globally inherit the _.bbclass_ and
  the entire Yocto project is checked.
- `WS_USERKEY` and `WS_APIKEY` are personal and can be found from the
  Mend web interface for your organization.
- `WS_PRODUCTNAME` is your desired product name: if a product with that
  name is already present, it will be updated; if it doesn't exist, its
  creation will be automatically handled by _meta-mend_.
- `MEND_URL` is the Mend environment URL of your shared instance.
  More information about this and the list of supported values
  can be found at this
  [link](https://docs.mend.io/platform/latest/authenticate-your-login-for-the-mend-cli#AuthenticateyourloginfortheMendCLI-MendCLI-mendauthloginparameters).
- `MEND_EMAIL` must be set to the email of the account
  corresponding to the `WS_USERKEY`.
- Note that `MEND_USER_KEY` is not required, as it is the same as
  `WS_USERKEY` and this is handled internally.


## PDF report generation

This meta-layer supports the generation of the report in PDF format
in addition to the json one.
To generate the PDF as well, add the following line to the
configuration:

```
    WS_ENABLE_PDF_REPORT = "1"
```

The report can then be found at:

```
build/tmp-glibc/log/mend/mend-report-YYYYMMDDhhmmss.zip
```

The file is a zipped version that contains the pdf reporting
