#!/bin/sh
# v0.4   - "dry-run" release
# v0.3.1 - "try to force Github to accept this change"-release
 
set -f
# set the following variables accordingly to your site
# the admin will get a notification mail in BCC 

# the following lines should be moved to a config file, eg. /usr/local/etc/cleanup_friendica.conf
#friendicapath="/var/www/net/nerdica.net/friendica"
#site="SITE"
#siteurl="https://domain.tld/"
#siteadmin="admin@domain.tld"
#sitefrom="no-reply@domain.tld"
#protectedusers="admin1 admin2 admin3"

case $1 in
	"--dry-run")
		mode="dryrun"
		;;
	"--dowhatimean")
		mode="hotrun"
		;;
	*)
		echo "Usage: "
		echo " --dry-run \t: make a dry-run, no deletion will be done, no mails are sent."
		echo " --dowhatimean \t: add this option if you really want to delete users."
		exit 0
		;;
esac

. /usr/local/etc/cleanup_friendica.conf

# make a list to be used for grep -E 
protected=$(echo $protectedusers | sed 's/\"//g' | sed 's/\ /\\\|/g')

cd ${friendicapath} || exit 0

# notify the user that s/he needs to re-login after 6 months to prevent account deletion
notifyUser () {
	( cat <<EOF  
Dear ${dispname}, 

you have registered on ${siteurl} ${registered} and last time you logged in was ${lastlogin}. 
Your latest post - if any - was ${lastpost}.

If you want to continue to keep your account on Nerdica then please log in at least every 6 months to keep your account alive. Otherwise we assume that you don't want to use it anymore and will cancel your account 7 months after your last login. 

You can access your profile at ${profileurl} or you can cancel your account on your own when logged in at ${siteurl}removeme - however we would like to see you become an active user again and contribute to the Fediverse, but of course it's up to you.  

Sincerely,
your ${site} admins
    		
EOF
	) | sed 's/_/\ /g' | /usr/bin/mail -s "The Fediverse misses you, ${username}!" -r "${sitefrom}" -- "${usermail}"
	# add '-b "$siteadmin"' before the "--" above to receive BCC mails 
}

# notify user that the account has been deleted because of inactivity
notifyUserDeletion () {
	( cat <<EOF  
Dear ${dispname}, 

you have registered on ${siteurl} ${registered} and last time you logged in was ${lastlogin}. 
Your latest post - if any - was ${lastpost}.

Since you haven't reacted to the previous mails and didn't login again, your account including all your data has now been deleted. 

Sincerely,
your ${site} admins
    		
EOF
	) | sed 's/_/\ /g' | /usr/bin/mail -s "Your account ${username} on ${site} has been be deleted!" -r "${sitefrom}" -- "${usermail}"
	# add '-b "$siteadmin"' before the "--" above to receive BCC mails 
}

# delete users that never logged in and never posted content
# filtering for "weeks" will result in accounts with 2 weeks old accounts, 
# filter for just "week" will do the same after 1 week.
# same should apply to "month" and "months", but untested.
for username in $( ${friendicapath}/bin/console user list active -c 10000 | grep 'never.*never' | grep weeks | awk '{print $2}') ; do 
	# if username is a protected user do nothing, else delete user
	if [ -n "${protectedusers}" ]; then
		pcheck=0
		for s in $(echo ${protectedusers}) ; do
			if [ "${s}" = "${username}" ]; then
				pcheck=1
			fi
		done
		if [ ${pcheck} -eq 0 ]; then
			echo "Delete unconfirmed user ${username}"
			if [ "${mode}" = "hotrun" ]; then
				${friendicapath}/bin/console user delete "${username}" -y
			elif [ "${mode}" = "dryrun" ]; then
				echo "${username}: skipped because of dryrun."
			fi
		fi
	fi
done

# find & notify users that didn't logged in >6 months and send mail to log in again
for u in $( ${friendicapath}/bin/console user list active -c 10000 | grep -v '.*---.*' | sed 's/|/;/g' | tr  -s "\ " | sed 's/^;\ //g' | sed 's/\ ;\ /;/g' | sed 's/\ /_/g' | tail -n +2 | grep -i -v -E ${protected} ); do 
	username=$(echo "${u}" | awk -F ";" '{print $1}')
	dispname=$(echo "${u}" | awk -F ";" '{print $2}')
	profileurl=$(echo "${u}"| awk -F ";" '{print $3}')
	usermail=$(echo "${u}" | awk -F ";" '{print $4}')
	registered=$(echo "${u}" | awk -F ";" '{print $5}')
	lastlogin=$(echo "${u}" | awk -F ";" '{print $6}')
	lastpost=$(echo "${u}" | awk -F ";" '{print $7}')
    res=$(echo "${lastlogin}" | grep -E '[6-9].months.*|1[012].months.*|[1-9].year.*')
    if [ -n "${res}" ]; then 
    	num_months=$(echo "${res}" | awk -F "_" '{ print $1}')
    	monthyear=$(echo "${res}" | awk -F "_" '{ print $2}' | sed -e 's/s//g')  # remove the "s" in months and years
    	if [ "${monthyear}" = "month" ] ; then
	    	if [ ${num_months} -ge 7 ] ; then
	    		DELUSER=true
	    	elif [ ${num_months} -eq 6 ]; then 
    			# mail the user and ask to re-login
		    	DELUSER=false
				if [ "${mode}" = "hotrun" ]; then
					#echo -n "hotrun  "
    				notifyUser
				elif [ "${mode}" = "dryrun" ]; then
					echo "Check ${username}: notify skipped because of dryrun."
				fi
	    	fi
	    elif [ "${monthyear}" = "year" ]; then
	    	DELUSER=true
	    fi
	    if  [ "${DELUSER}" = "true" ]; then
    		# delete account when last login is older than 7 months and send mail about deletion
    		# you should copy & paste the text from 6 months for the first runs of this script
    		# and later change the text to a notification that the account has been deleted. 
			# if username is a protected user do nothing, else delete user
			if [ -n "${protectedusers}" ]; then
				pcheck=0
				for s in $(echo ${protectedusers}) ; do
					if [ "${s}" = "${username}" ]; then
						pcheck=1
					fi
				done
				if [ ${pcheck} -eq 0 ]; then
					echo -n "Deleting user ${username}... "
					if [ "${mode}" = "hotrun" ]; then
						#echo -n "hotrun  "
						${friendicapath}/bin/console user delete "${username}" -y
						notifyUserDeletion
						echo "deleted."
					elif [ "${mode}" = "dryrun" ]; then
						echo "skipped because of dryrun."
					fi
				fi
			fi
		fi
    fi
done
