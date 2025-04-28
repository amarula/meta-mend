MEND_LOG_LEVEL ?= "debug"

HOSTTOOLS += "java"

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

do_mend_check() {

    if [ -z "${WS_USERKEY}" ] || [ -z "${WS_APIKEY}" ] || [ -z "${WS_PRODUCTNAME}" ]; then
      exit 0
    fi

    unified_agent_cmd="java -jar /builder/wss-unified-agent.jar -logLevel \"${MEND_LOG_LEVEL}\" -userKey \"${WS_USERKEY}\" -apiKey \"${WS_APIKEY}\" -c /builder/amarula.wss.config -d \"${S}\" -product \"${WS_PRODUCTNAME}\" -project \"${BPN}\""

    echo "Executing Mend Unified Agent command: ${unified_agent_cmd}"

    eval "${unified_agent_cmd}"

    echo "Mend Unified Agent scan completed."
}

addtask mend_check after do_patch before do_build
do_mend_check[nostamp] = "1"
do_rootfs[recrdeptask] += "do_mend_check"
