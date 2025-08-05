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

def mend_request(encoded_data):
    import urllib.request

    response = ""
    httprequest = urllib.request.Request(
        method="POST",
        url="https://saas-eu.whitesourcesoftware.com/api/v1.4",
        data=encoded_data,
        headers={"Content-Type": "application/json"},
    )

    with urllib.request.urlopen(httprequest) as httpresponse:
        response = httpresponse.read().decode() if httpresponse.status == 200 else ""

    return response


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

    if not d.getVar("WS_USERKEY") or not d.getVar("WS_APIKEY"):
        return

    try:
        # Get PRODUCT TOKEN from PRODUCT NAME:
        data = json.dumps(
            {
                "requestType": "getOrganizationProductTags",
                "userKey": d.getVar('WS_USERKEY'),
                "orgToken": d.getVar('WS_APIKEY')
            }
        )

        res = mend_request(data.encode())
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
                "userKey": d.getVar('WS_USERKEY'),
                "productToken": product_token
            }
        )

        res = mend_request(data.encode())

        if res == "":
            raise Exception("HTTP Response error.")

        response_json = json.loads(res)
        timestamp = datetime.datetime.now().strftime('%Y%m%d%H%M%S')
        out_path = os.path.join(d.getVar('MEND_CHECK_SUMMARY_DIR'), "mend-report-%s.json" % (timestamp))

        os.makedirs(d.getVar('MEND_CHECK_SUMMARY_DIR'), exist_ok=True)

        with open(out_path, "w") as f:
            json.dump(response_json, f, indent=2)
        bb.note(f"Mend report succesfully generated at {out_path}")

    except Exception as err:
        bb.warn(f"Generating Mend report failed. Details: {err}")
}

addhandler mend_report_handler
mend_report_handler[eventmask] = "bb.event.BuildCompleted"


python do_mend_check() {
    from oe.cve_check import get_patched_cves
    import json

    if not d.getVar("WS_USERKEY") or not d.getVar("WS_APIKEY") or not d.getVar("WS_PRODUCTNAME"):
        return

    # Don't run package scan on native package
    if not d.getVar('CLASSOVERRIDE') == 'class-target':
        return

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

            res = mend_request(data.encode())
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

                res = mend_request(data.encode())
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

            res = mend_request(data.encode())
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

            res = mend_request(data.encode())
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

            res = mend_request(data.encode())
            if res == "":
                raise Exception("HTTP Response error.")

        except Exception as err:
            bb.warn(f"Ignoring alerts process failed. Details: {err}")

    unified_agent_cmd = f"MEND_BASEDIR={d.getVar('WORKDIR')} {d.getVar('MEND_CLI_PATH')} ua -userKey \"{d.getVar('WS_USERKEY')}\" -apiKey \"{d.getVar('WS_APIKEY')}\" -c \"{d.getVar('WS_AGENT_CONFIG')}\" -d \"{d.getVar('S')}\" -product \"{d.getVar('WS_PRODUCTNAME')}\" -project \"{d.getVar('BPN')}\""

    bb.note(f"Executing Mend Unified Agent command: {unified_agent_cmd}")

    bb.process.run(unified_agent_cmd)

    bb.note("Mend Unified Agent scan completed.")
}

addtask mend_check after do_patch before do_build
do_mend_check[nostamp] = "1"
do_rootfs[recrdeptask] += "do_mend_check"
