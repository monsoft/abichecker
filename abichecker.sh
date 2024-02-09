#!/bin/bash

# abichecker ver 0.2
# by Irek 'Monsoft' Pelech (c) 2023,2024
# 
# Require curl, jq, logger
#

# Logging to mail log
readonly SCRIPT_NAME="$(basename $0|sed 's/\.sh//g')[$$]"

# abuseipdb.com API token
TOKEN=XXX

# Api url
API_URL="api.abuseipdb.com/api/v2/check"

# SMTP response message
SMTP_DENY_MESSAGE="Bad host reputation."

# SMTP deny code
SMTP_DENY_CODE="521"

# Abuse score used in check. Mails above this score will be rejected.
ABUSE_SCORE=70

# App configuration directory
CONF_DIR="/opt"
HOSTNAME_WHITELIST_DOMAINS="${CONF_DIR}/abichecker/hostname_domain_whitelist.txt"

# Functions
check_commands () {
	if ! command -v $1 &> /dev/null; then
		echo "$1 could not be found. Please install $1" | logger -p mail.info -t ${SCRIPT_NAME}
		exit 1
	fi
}

email_allow () {
	# We are allowing access
#	echo "action=ok"
	echo "action=dunno"
	echo ""
	exit 0
}

email_deny () {
	# We are denying access
	echo "action=${SMTP_DENY_CODE} ${SMTP_DENY_MESSAGE}"
	echo ""
	exit 0
}
# Check if curl & jq are installed
check_commands curl
check_commands jq
check_commands logger

# Load variables passed by Postfix
while read attr; do
	[ -z "$attr" ] && break
	eval $attr
done

if [ -z "$client_address" ]; then
	echo "No variables passed by Postfix" | logger -p mail.info -t ${SCRIPT_NAME}
	exit 1
fi

# Check if client whitelisted by domain
if [ ! -z "${client_name}" ]; then
	if [ -f "${HOSTNAME_WHITELIST_DOMAINS}" ]; then
		while IFS= read -r domain; do
			if [ -n "$domain" ]; then
				if [[ "${client_name}" =~ "${domain}" ]]; then
					echo "Host ${client_name} whitelisted by domain." | logger -p mail.info -t ${SCRIPT_NAME}
					email_allow
				fi
			fi
		done < "${HOSTNAME_WHITELIST_DOMAINS}"
	fi
fi

REPORT_JSON=$(curl -s -G https://${API_URL} --data-urlencode "ipAddress=$client_address" -H "Key: ${TOKEN}" -H "Accept: application/json")

if [[ ! "${REPORT_JSON}" =~ "ipAddress" ]]; then
	echo "Unable to fetch data from abuseipdb.com API. Please check connection." | logger -p mail.info -t ${SCRIPT_NAME}
	exit 1
fi

# Parsing JSON into variables
ABUSE_CONFIDENCE_SCORE=$(echo "${REPORT_JSON}"|jq -r .data.abuseConfidenceScore)

if [ "${ABUSE_CONFIDENCE_SCORE}" -gt "${ABUSE_SCORE}" ]; then
	# We are denying access
	echo "Email from host ${client_name}[$client_address] denied. Abuse Score ${ABUSE_CONFIDENCE_SCORE}%." | logger -p mail.info -t ${SCRIPT_NAME}
	email_deny
else
	# We are allowing access
	echo "Email from host ${client_name}[$client_address] allowed. Abuse Score ${ABUSE_CONFIDENCE_SCORE}%." | logger -p mail.info -t ${SCRIPT_NAME}
	email_allow
fi
