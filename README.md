# abichecker

This is another very simple plugin for Postfix SMTP server to block access from IPs which have bad reputation. We are living in very danger times and even small and simple script like this one, can make you and your server more secure.

This script use data and API provided by <a href="https://www.abuseipdb.com" target="_blank">AbuseIPDB</a> project. API is free up to 3000 checks per day so if your SMTP server is quite busy, you will have to look for paid access.

## Installation & configuration ##

* Clone repository to /opt directory
```
git clone https://github.com/monsoft/abichecker.git
```
* Setup executable bit on `abichecker.sh` script:
```
cd /opt/abichecker
chmod 755 abichecker.sh
```
* Instal curl and jq application on your system

Debian/Ubuntu:
```
sudo apt install -y curl jq
```
Red Hat/CentOs/Rocky Linux/AlmaLinux:
```
sudo dnf install -y curl jq
```
* Create account on <a href="https://www.abuseipdb.com" target="_blank">AbuseIPDB</a> project and create API Key by going to `AbuseIPDB->User Account->API` and click `Create Key`.
* Copy API Key and modify variable `TOKEN` in `abichecker.sh` script.
* Add below lines to the end of Postfix master.cf file:
```
abichecker   unix  -       n       n       -       0       spawn
  user=abichecker argv=/opt/abichecker/abichecker.sh
```
* Add below line to Postfix `main.cf` file under `smtpd_client_restrictions` :
```
smtpd_client_restrictions = 
  ...
  check_policy_service unix:private/abichecker
```
* Crete system user & group:
```
sudo adduser --quiet --system --group --no-create-home --home /nonexistent abichecker
```
* Restart Postfix service
* Check your Postfix logs

After some times you can check logs for lines like this one:
```
Feb  9 11:12:47 mail1 abichecker[6761]: Email from host unknown[x.x.x.x] denied. Abuse Score 71%.

NOQUEUE: reject: RCPT from unknown[x.x.x.x]: 521 5.7.1 <unknown[x.x.x.x]>: Client host rejected: Bad host reputation.; from=<spameri@tiscali.it> to=<spameri@tiscali.it> proto=ESMTP helo=<xxxxxxxx>
```
This mean that check found IP which already exist in AbuseIPDB database and its reputation is equal or higher than 70% (this can be changed in script by tweaking variable `ABUSE_SCORE`) then reject connetion from that IP. 

Sometimes IPs of legitimaed services like MS Outlook are reported to AbuseIPDB by automatic reports. To allow reciving emails from these domains, you can whitelist them by adding them to file `hostname domain whitelist.txt` located in `/opt/abichecker/`. One domain/subdomain per line:
```
phx.paypal.com
outbound.protection.outlook.com
```

## Debuging Postfix ##

Sometimes you may find yourself in situation that require to see what Postfix is doing on lower level (happen to me multiple times during writing check policy service scripts). To do this, edit master.cf file and add option `-v` to smtp line so it will looks like this:
```
# ==========================================================================
# service type  private unpriv  chroot  wakeup  maxproc command + args
#               (yes)   (yes)   (no)    (never) (100)
# ==========================================================================
smtp      inet  n       -       y       -       -       smtpd -v
```
After saving this file, restart postfix service. Try to send few emails to your mail server and check your Postfix log file. It will be much bigger than usual and it will be growing fast.<br>
When you finish your investigation, remove added `-v` from smtp line.

## Participate in AbuseIPDB Project ##
This ofcouse is optional, but if you for example use <a href="https://www.fail2ban.org" target="_blank">Fail2ban</a> software, you can help in AbuseIPDB Project by configuring Fail2ban to report IPs that show the malicious signs. This will benefit you and all of us using this project.
