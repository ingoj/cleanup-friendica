# cleanup-friendica
This is a small cleanup script for Friendica node admins to help with forgotten or dead accounts. 

The script does two things: 
1. delete all users after a week that haven't logged in at all and didn't post anything (filter `weeks` and `never.*never`)
2. search for accounts that haven't logged in for 6 months, send them a reminder mail and delete accounts that haven't logged within 7 months

# Installation
* save the script to your disk where your webserver user or the user running Friendica can access it (e.g. not under /root, maybe /usr/local/bin)
* make the script executable (e.g. `chown www-data:www-data /path/to/cleanup_friendica.sh && chmod ug+rx /path/to/cleanup_friendica.sh)`
* create a crontab to execute the script, e.g.: `16 9      2,15 * *      /usr/local/bin/cleanup_friendica.sh` to execute the script every two weeks
* for the first 2 runs you should have the mail text the same and keep the deleting of the user commented out (line 54 in initial commit). After the first 2 runs you should change the first mail text to send out a mail that the account has been deleted because of inactivity and not reacting to the prior sent mails. 
* change the variables at the begin of the script to your site settings. 

# Usage
`Usage:
 --dry-run      : make a dry-run, no deletion will be done, no mails are sent.
 --dowhatimean  : add this option if you really want to delete users.`

# Other useful tips
* the script expects the output of `bin/console` to be in `LANG=en_US.UTF-8` or `en`
* you can change the mail command from `-b ${siteadmin} -- ${usermail}` to `-- ${siteadmin}` and comment out all lines with `bin/console user delete` statement for testing runs
* before putting this script into production you may want to inform your users via the notify_all addon of the upcoming changes/deletions. 
