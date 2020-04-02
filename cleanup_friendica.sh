#!/bin/sh

# set the following variables accordingly to your site
# the admin will get a notification mail in BCC 

# the following lines should be moved to a config file, eg. /usr/local/etc/cleanup_friendica.conf
#friendicapath="/var/www/net/nerdica.net/friendica"
#site="SITE"
#siteurl="https://domain.tld/"
#siteadmin="admin@domain.tld"
#sitefrom="no-reply@domain.tld"
#protectedusers="admin1 admin2 admin3"

source /usr/local/etc/cleanup_friendica.conf


cd ${friendicapath} || exit 0

# delete users that never logged in and never posted content
# filtering for "weeks" will result in accounts with 2 weeks old accounts, 
# filter for just "week" will do the same after 1 week.
# same should apply to "month" and "months", but untested.
for username in $( ${friendicapath}/bin/console user list active -c 10000 | grep 'never.*never' | grep weeks | awk '{print $2}') ; do 
	# if username is a protected user do nothing, else delete user
	if [[ "${protectedusers}" == *"${username}"* ]]; then
		:
	else
		${friendicapath}/bin/console user delete "${username}" -q
	fi
done

# find & notify users that didn't logged in >6 months and send mail to log in again
for u in $( ${friendicapath}/bin/console user list active -c 10000 | grep -v '.*---.*' | sed 's/|/;/g' | tr  -s "\ " | sed 's/^;\ //g' | sed 's/\ ;\ /;/g' | sed 's/\ /_/g' | tail -n +2 ); do 
	username=$(echo "${u}" | awk -F ";" '{print $1}')
	dispname=$(echo "${u}" | awk -F ";" '{print $2}')
	profileurl=$(echo "${u}"| awk -F ";" '{print $3}')
	usermail=$(echo "${u}" | awk -F ";" '{print $4}')
	registered=$(echo "${u}" | awk -F ";" '{print $5}')
	lastlogin=$(echo "${u}" | awk -F ";" '{print $6}')
	lastpost=$(echo "${u}" | awk -F ";" '{print $7}')
    #echo "Userinfo: ${username},${dispname},${profileurl},${usermail},${registered},${lastlogin},${lastpost}"
    res=$(echo "${lastlogin}" | grep '[6-9]_months.*')
    if [ -n "${res}" ]; then 
    	num_months=$(echo "${res}" | awk -F "_" '{ print $1}')
    	#echo "months: ${num_months}"
    	if [ ${num_months} -ge 7 ]; then 
    		# delete account when last login is older than 7 months and send mail about deletion
    		# you should copy & paste the text from 6 months for the first runs of this script
    		# and later change the text to a notification that the account has been deleted. 
    		( cat <<EOF  
Dear ${dispname}, 

you have registered on ${siteurl} ${registered} and haven't logged in again ${lastlogin}. 
Your latest post - if any - was ${lastpost}.

If you want to continue to keep your account on Nerdica then please log in at least every 6 months to keep your account alive. Otherwise we assume that you don't want to use it anymore and will cancel your account 7 months after your last login. 

You can access your profile at ${profileurl} or you can cancel your account on your own when logged in at ${siteurl}/removeme - however we would like to see you become an active user again and contribute to the Fediverse, but of course it's up to you.  

Sincerely,
your ${site} admins
    		
EOF
) | sed 's/_/\ /g' | /usr/bin/mail -s "The Fediverse misses you, ${username}!" -r "${sitefrom}" -b "$siteadmin" -- "${usermail}"
		# if username is a protected user do nothing, else delete user
		if [[ "${protectedusers}" == *"${username}"* ]]; then
			:
		else
			# ${friendicapath}/bin/console user delete "${u}" -q
		fi
    	elif [ ${num_months} -eq 6 ]; then 
    		# mail the user and ask to re-login
    		( cat <<EOF  
Dear ${dispname}, 

you have registered on ${siteurl} ${registered} and haven't logged in again ${lastlogin}. 
Your latest post - if any - was ${lastpost}.

If you want to continue to keep your account on Nerdica then please log in at least every 6 months to keep your account alive. Otherwise we assume that you don't want to use it anymore and will cancel your account 7 months after your last login. 

You can access your profile at ${profileurl} or you can cancel your account on your own when logged in at ${siteurl}/removeme - however we would like to see you become an active user again and contribute to the Fediverse, but of course it's up to you.  

Sincerely,
your ${site} admins
    		
EOF
) | sed 's/_/\ /g' | /usr/bin/mail -s "The Fediverse misses you, ${username}!" -r "${sitefrom}" -b "$siteadmin" -- "${usermail}"
    	fi
    fi
done
