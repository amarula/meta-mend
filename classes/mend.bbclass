MEND_LOG_LEVEL ?= "debug"
MEND_CHECK_SUMMARY_DIR ?= "${LOG_DIR}/mend/"

HOSTTOOLS += "java"

MEND_LATEST_LOG_NAME = "latest.json"

AUTO_PATCH = "true"

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
    if not e.data.getVar("WS_USERKEY"):
        missing_vars.append("WS_USERKEY")
    if not e.data.getVar("WS_APIKEY"):
        missing_vars.append("WS_APIKEY")
    if not e.data.getVar("WS_PRODUCTNAME"):
        missing_vars.append("WS_PRODUCTNAME")

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

    try:
        data = json.dumps(
            {
                "requestType": "getProductAlerts",
                "userKey": d.getVar('WS_USERKEY'),
                "productToken": d.getVar('WS_PRODUCTTOKEN')
            }
        )

        res = mend_request(data.encode())

        if res == "":
            raise Exception("HTTP Response error.")

        response_json = json.loads(res)
        timestamp = datetime.datetime.now().strftime('%Y%m%d%H%M%S')
        out_path = os.path.join(d.getVar('MEND_CHECK_SUMMARY_DIR'), "mend-report-%s.json" % (timestamp))
        link_path = os.path.join(d.getVar('MEND_CHECK_SUMMARY_DIR'), d.getVar('MEND_LATEST_LOG_NAME'))

        os.makedirs(d.getVar('MEND_CHECK_SUMMARY_DIR'), exist_ok=True)

        with open(out_path, "w") as f:
            json.dump(response_json, f, indent=2)
        os.system(f"ln {out_path} {link_path}")
        bb.note(f"Mend report succesfully generated at {out_path}")
        bb.note(f"Latest report can also be accessed at {link_path}")
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

    patched_cves = get_patched_cves(d)

    if patched_cves:
        bb.note(f"Found {d.getVar('BPN')} patched cves: {patched_cves}")

        try:
            # GET PROJECT TOKEN FROM PACKAGE NAME
            data = json.dumps(
                {
                    "requestType": "getAllProjects",
                    "userKey": d.getVar('WS_USERKEY'),
                    "productToken": d.getVar('WS_PRODUCTTOKEN')
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

    unified_agent_cmd = f"java -jar /builder/wss-unified-agent.jar -logLevel \"{d.getVar('MEND_LOG_LEVEL')}\" -userKey \"{d.getVar('WS_USERKEY')}\" -apiKey \"{d.getVar('WS_APIKEY')}\" -c \"/builder/amarula.wss.config\" -d \"{d.getVar('S')}\" -product \"{d.getVar('WS_PRODUCTNAME')}\" -project \"{d.getVar('BPN')}\""

    bb.note(f"Executing Mend Unified Agent command: {unified_agent_cmd}")

    bb.process.run(unified_agent_cmd, shell=True)

    bb.note("Mend Unified Agent scan completed.")
}


python download_patches() {
    import sys
    # bb.note(f"CWD = {sys.path}")
    if not d.getVar("AUTO_PATCH") == "true":
        return
    from patch_download import get_patches
    bb.note(f"Downloading patches...")
    save_path = os.path.join(d.getVar('MEND_CHECK_SUMMARY_DIR'), d.getVar('MEND_LATEST_LOG_NAME'))
    get_patches(save_path, "temp")
    bb.note(f"Patches downloaded and saved in 'temp' directory")
}

addhandler download_patches
download_patches[eventmask] = "bb.event.BuildCompleted"
download_patches[deptask] = "mend_report_handler"

addtask mend_check after do_patch before do_build
do_mend_check[nostamp] = "1"
do_rootfs[recrdeptask] += "do_mend_check"
