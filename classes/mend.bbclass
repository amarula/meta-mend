MEND_VERSION = "25.7.1"
MEND_CHECK_SUMMARY_DIR ?= "${LOG_DIR}/mend/"
MEND_LOG_LEVEL ?= "DEBUG"
export MEND_LOG_LEVEL

WS_AGENT_CONFIG ??= "/work/meta-mend/files/mend.wss.config"

MEND_CLI_PATH ?= "/work/meta-mend/files/mend_${MEND_VERSION}"

MEND_USER_KEY = "${WS_USERKEY}"
export MEND_USER_KEY
export MEND_URL
export MEND_EMAIL

export BB_ENV_PASSTHOUGH_ADDITIONS = "$BB_ENV_PASSTHROUGH_ADDITIONS MEND_URL MEND_USER_KEY MEND_EMAIL"

def mend_request(url, encoded_data):
    import urllib.request

    response = ""
    httprequest = urllib.request.Request(
        method="POST",
        url=f"{url}/api/v1.4",
        data=encoded_data,
        headers={"Content-Type": "application/json"},
    )

    with urllib.request.urlopen(httprequest) as httpresponse:
        response = httpresponse.read().decode() if httpresponse.status == 200 else ""

    return response


def mend_request_raw(url, encoded_data):
    import urllib.request

    httprequest = urllib.request.Request(
        method="POST",
        url=f"{url}/api/v1.4",
        data=encoded_data,
        headers={"Content-Type": "application/json"},
    )

    with urllib.request.urlopen(httprequest) as httpresponse:
        if httpresponse.status == 200:
            return httpresponse.read()
        return


def mend_get_async_report(url, request_type, out_format, credentials, product_token):
    import json
    import time

    data = json.dumps(
        {
            "requestType": "generateProductReportAsync",
            "reportType": request_type,
            "format": out_format,
            "productToken": product_token,
            "userKey": credentials['user_key']
        }
    )

    res = mend_request(url, data.encode())

    if res == "":
        raise Exception("HTTP Response error.")

    response_json = json.loads(res)
    status_data = response_json.get("asyncProcessStatus")

    if status_data:
        product_uuid = status_data.get('uuid')
    else:
        return "";

    start_time = time.time()

    while True:
        if time.time() - start_time > 1200:
            raise Exception("Timeout waiting server response.")

        data = json.dumps(
            {
                 "requestType": "getAsyncProcessStatus",
                 "orgToken": credentials['org_token'],
                 "userKey": credentials['user_key'],
                 "uuid": product_uuid
            }
        )
        res = mend_request(url, data.encode())

        if res == "":
            raise Exception("HTTP Response error.")

        response_json = json.loads(res)
        status_data =  response_json.get("asyncProcessStatus")

        if status_data:
            status = status_data.get("status")

        if status == "SUCCESS":
            bb.debug(1, "Mend json SUCCESS")
            return product_uuid
        if status == "FAILED":
            bb.debug(1, "Mend json FAILED")
            return ""
        if status == "IN_PROGRESS" or status == "PENDING":
            bb.debug(1, f"Mend json {status}")
            time.sleep(5)


python mend_check_warn_handler() {
    # Only warn once
    if getattr(bb.event, 'mend_warned', False):
        return

    missing_vars = []
    if not d.getVar("WS_USERKEY"):
        missing_vars.append("WS_USERKEY")
    if not d.getVar("WS_APIKEY"):
        missing_vars.append("WS_APIKEY")
    if not d.getVar("WS_PRODUCTNAME"):
        missing_vars.append("WS_PRODUCTNAME")
    if not d.getVar("MEND_URL"):
        missing_vars.append("MEND_URL")
    if not d.getVar("MEND_EMAIL"):
        missing_vars.append("MEND_EMAIL")

    if missing_vars:
        bb.warn(f"The following variables must be set in local.conf or a recipe for mend checking to function: {', '.join(missing_vars)}")

    # Set flag to avoid repeating
    setattr(bb.event, 'mend_warned', True)
}

addhandler mend_check_warn_handler
mend_check_warn_handler[eventmask] = "bb.event.ParseStarted"


python mend_report_handler() {
    import json
    import datetime

    if not d.getVar("WS_USERKEY") or not d.getVar("WS_APIKEY") or not d.getVar("MEND_URL"):
        return

    credentials = {
        'user_key': d.getVar("WS_USERKEY"),
        'org_token': d.getVar("WS_APIKEY")
    }

    mend_url = d.getVar("MEND_URL")

    try:
        # Get PRODUCT TOKEN from PRODUCT NAME:
        data = json.dumps(
            {
                "requestType": "getOrganizationProductTags",
                "userKey": d.getVar('WS_USERKEY'),
                "orgToken": d.getVar('WS_APIKEY')
            }
        )

        res = mend_request(mend_url, data.encode())
        if res == "":
            raise Exception("HTTP Response error.")

        response_json = json.loads(res)

        product_token = ""
        for product in response_json.get("productTags", []):
            if product.get("name") == d.getVar("WS_PRODUCTNAME"):
                product_token = product.get("token")
                break

        data = json.dumps(
            {
                "requestType": "getProductAlerts",
                "userKey": credentials['user_key'],
                "productToken": product_token
            }
        )

        res = mend_request(mend_url, data.encode())

        if res == "":
            raise Exception("HTTP Response error.")

        response_json = json.loads(res)
        timestamp = datetime.datetime.now().strftime('%Y%m%d%H%M%S')
        out_path = os.path.join(d.getVar('MEND_CHECK_SUMMARY_DIR'), "mend-report-%s.json" % (timestamp))

        os.makedirs(d.getVar('MEND_CHECK_SUMMARY_DIR'), exist_ok=True)

        with open(out_path, "w") as f:
            json.dump(response_json, f, indent=2)
        bb.note(f"Mend report succesfully generated at {out_path}")

        if d.getVar("WS_ENABLE_PDF_REPORT") == "1":

            res = mend_get_async_report(mend_url, "RiskReport", "pdf", credentials, product_token)
            if res == "":
                raise Exception("Unable to download the report.")

            data = json.dumps(
                    {
                    "requestType": "downloadAsyncReport",
                    "orgToken": d.getVar('WS_APIKEY'),
                    "userKey": d.getVar('WS_USERKEY'),
                    "reportStatusUUID": res
                    }
            )

            zip_content = mend_request_raw(mend_url, data.encode())

            if zip_content:
                zip_out_path = os.path.join(d.getVar('MEND_CHECK_SUMMARY_DIR'), "mend-report-%s.zip" % (timestamp))
                with open(zip_out_path, "wb") as f:
                    f.write(zip_content)
                bb.note(f"Mend PDF report successfully generated at {zip_out_path}")
            else:
                raise Exception("HTTP Response error when requesting report.")

    except Exception as err:
        bb.warn(f"Generating Mend report failed. Details: {err}")
}

addhandler mend_report_handler
mend_report_handler[eventmask] = "bb.event.BuildCompleted"


python do_mend_check() {
    from oe.cve_check import get_patched_cves
    import json

    if not d.getVar("WS_USERKEY") or not d.getVar("WS_APIKEY") or not d.getVar("WS_PRODUCTNAME") or not d.getVar("MEND_URL"):
        return

    # Don't run package scan on native package
    if not d.getVar('CLASSOVERRIDE') == 'class-target':
        return

    mend_url = d.getVar("MEND_URL")

    patched_cves = get_patched_cves(d)

    if patched_cves:
        bb.note(f"Found {d.getVar('BPN')} patched cves: {patched_cves}")

        try:
            # GET PRODUCT TOKEN FROM PRODUCT NAME
            data = json.dumps(
                {
                    "requestType": "getOrganizationProductTags",
                    "userKey": d.getVar('WS_USERKEY'),
                    "orgToken": d.getVar('WS_APIKEY')
                }
            )

            res = mend_request(mend_url, data.encode())
            if res == "":
                raise Exception("HTTP Response error.")

            response_json = json.loads(res)

            product_token = ""
            for product in response_json.get("productTags", []):
                if product.get("name") == d.getVar("WS_PRODUCTNAME"):
                    product_token = product.get("token")
                    break

            if product_token == "":
                # CREATE PRODUCT
                data = json.dumps(
                    {
                        "requestType": "createProduct",
                        "userKey": d.getVar('WS_USERKEY'),
                        "productName": d.getVar('WS_PRODUCTNAME'),
                        "orgToken": d.getVar('WS_APIKEY')
                    }
                )

                res = mend_request(mend_url, data.encode())
                if res == "":
                    raise Exception("HTTP Response error.")

                response_json = json.loads(res)
                product_token = response_json['productToken']

            # GET PROJECT TOKEN FROM PACKAGE NAME
            data = json.dumps(
                {
                    "requestType": "getAllProjects",
                    "userKey": d.getVar('WS_USERKEY'),
                    "productToken": product_token
                }
            )

            res = mend_request(mend_url, data.encode())
            if res == "":
                raise Exception("HTTP Response error.")

            response_json = json.loads(res)
            package_name = d.getVar('BPN')
            project_token = ""
            for project in response_json.get("projects", []):
                if project.get("projectName") == package_name:
                    project_token = project.get("projectToken")
                    break

            # GET VULNERABILITY UUIDs FROM CVE CODES
            data = json.dumps(
                {
                    "requestType": "getProjectAlerts",
                    "userKey": d.getVar('WS_USERKEY'),
                    "projectToken": project_token
                }
            )

            res = mend_request(mend_url. data.encode())
            if res == "":
                raise Exception("HTTP Response error.")

            response_json = json.loads(res)
            alert_uuids = []
            for alert in response_json.get("alerts", []):
                if alert.get("vulnerability", {}).get("name") in patched_cves:
                    alert_uuids.append(alert.get("alertUuid"))

            # SET MEND TO IGNORE PATCHED VULNERABILITIES
            data = json.dumps(
                {
                    "requestType": "ignoreAlerts",
                    "orgToken": d.getVar('WS_APIKEY'),
                    "userKey": d.getVar('WS_USERKEY'),
                    "alertUuids": alert_uuids,
                    "comments": "Automatically ignored by Mend utility",
                }
            )

            res = mend_request(mend_url, data.encode())
            if res == "":
                raise Exception("HTTP Response error.")

        except Exception as err:
            bb.warn(f"Ignoring alerts process failed. Details: {err}")

    unified_agent_cmd = f"MEND_BASEDIR={d.getVar('WORKDIR')} {d.getVar('MEND_CLI_PATH')} ua -userKey \"{d.getVar('WS_USERKEY')}\" -apiKey \"{d.getVar('WS_APIKEY')}\" -c \"{d.getVar('WS_AGENT_CONFIG')}\" -d \"{d.getVar('S')}\" -wss.url \"{mend_url}/agent\" -product \"{d.getVar('WS_PRODUCTNAME')}\" -project \"{d.getVar('BPN')}\""

    bb.note(f"Executing Mend Unified Agent command: {unified_agent_cmd}")

    bb.process.run(unified_agent_cmd)

    bb.note("Mend Unified Agent scan completed.")
}

addtask mend_check after do_patch before do_build
do_mend_check[nostamp] = "1"
do_rootfs[recrdeptask] += "do_mend_check"
