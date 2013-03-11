#!/bin/zsh -f
# add a short URL to a .htaccess on a remote server via SSH
#	GIST:	https://gist.github.com/tjluoma/4752908
# From:	Timothy J. Luoma
# Mail:	luomat at gmail dot com
# Date:	2013-02-10

NAME="$0:t"



	# 'die' is 'exit 1' but we get to include a message too
	#
die ()
{
	echo "$NAME: $@"
	exit 1
}



if [[ "$#" != "2" ]]
then
		die "$NAME: requires two arguments: /short http://remote"

fi


	# this is the server where the .htaccess file is located. It is assumed that you already have password-less SSH enabled
SERVER='nightwing.dreamhost.com'

	# This is the remote path to the .htaccess file
HTACCESS='luo.ma/.htaccess'

	# This is to be used as the base URL for the 'short URLs' that we will make
BASE='http://luo.ma'

####|####|####|####|####|####|####|####|####|####|####|####|####|####|####
#
#	A little basic sanity checking

case "$2" in
	http://*|https://*)
							# The argument is a valid URL, well, at least that
							# it starts with http:// or https://
							# I suppose I might want to make a gopher:// link someday
							# but that seems less likely.
						URL="$2"
	;;

	*)
						die "$NAME: 2nd argument is neither an http or https URL"

	;;

esac


case "$1" in
	http://*|https://*)
						die "$NAME: The 1st argument is NOT supposed to start with http or https"

	;;

	*)						# If we get here, The argument is NOT an URL
							# That check is in case I get the order mixed up


							# remove everything that is not a letter, number, or _ or - or +
						SHORT=$(echo "$1" | tr -dc '[:alnum:]-_+')

							# if we changed the short, based on the above, let the user know
						if [ "$SHORT" != "$1" ]
						then
								echo "$NAME: NOTE $1 was changed to $SHORT"
						fi

	;;

esac

####|####|####|####|####|####|####|####|####|####|####|####|####|####|####

	# put together the base URL and the new short name
SHORTURL="${BASE}/$SHORT"

	# check to make sure that the URL we are trying to make doesn't already exist
STATUS=($(curl -sL --head "$SHORTURL" | egrep -i '^(HTTP|Location:)' | awk '{print $2}' | tr -d '\r'))

	# we WANT this to be 404, which means that it doesn't exist yet
if [[ "$STATUS[1]" != "404" ]]
then

	# if we get here, then the SHORTURL we were going to create already exists, so we check to to see where it leads

		if [ "$STATUS[1]" = "302" -o  "$STATUS[1]" = "301" ]
		then

				# if we found a 301 or 302 maybe we already made the redirect we intended to make here
				# This is what happens when you get old and your memory starts to go
			ACTUALURL="$STATUS[2]"

				# is the URL we intended to make the same as the URL that already exists?
			if [ "$URL" = "$ACTUALURL" ]
			then
						# If we get here, then the URL we wanted to make is already in place
						# which is an OK result, so we copy it to the pasteboard and exit cleanly
					echo "$NAME: $SHORTURL is already set to $ACTUALURL"
			 		echo "$SHORTURL" | pbcopy
					exit 0
			else
						# if we get here, then we are already using a DIFFERENT URL
						# for the same short name. That's not so good, so we exit uncleanly
					die "$NAME: $SHORTURL is set to different URL: $ACTUALURL"

			fi

		fi

			# if we get here, well, the link exists but it is not a 301/302 so we just report that and exit
		die "$NAME: $SHORTURL already exists but is NOT a redirect."


fi



#
#		If we get here, we are good to go to create the new link
#



	# Now we'll add the information to the remote .htaccess, adding a new extra linefeeds for good measure.
	# A little extra whitespace never hurt anyone.
	# Except python users, I suppose.

ssh "${SERVER}" "/bin/echo \"
redirect 302 /${SHORT} $2
\" >> ${HTACCESS}" || die "Failed to add $SHORTURL to $HTACCESS on $SERVER"

echo "$NAME: Checking results for $SHORTURL..."

INFO=($(curl -sL --head "$SHORTURL" | egrep -i '^(HTTP|Location:)' | awk '{print $2}' | tr -d '\r'))

	# This will be the first status line which should be 302
STATUS1="$INFO[1]"

	# this will be the second status line which should be 200
STATUS2="$INFO[3]"

	# This will be the URL which should be the same as $URL
NEWURL="$INFO[2]"

# Now let's compare what we got with what we expected to get

if [[ "$STATUS1" != "302" ]]
then
	die "$NAME: $SHORTURL was not successfully added (STATUS1 is not 302)"

fi

if [[ "$STATUS2" != "200" ]]
then
	die "$NAME: $SHORTURL was not successfully added (STATUS2 is not 200)"

fi

if [[ "$NEWURL" = "$URL" ]]
then
			# this is where we should get to most of the time
 		echo "$NAME: $SHORTURL verified. Ready to paste"
 		echo "$SHORTURL" | pbcopy
 		exit 0
else
			# if the URL we redirect to ends up redirecting somewhere else, we could get here
 		echo "$NAME: $SHORTURL verified but different ($NEWURL instead of $URL). Ready to paste"
 		echo "$SHORTURL" | pbcopy
 		exit 0
fi

	# Well we shouldn't get here, but who knows, it's possible...
echo "$NAME: Unknown error"

die "We reached the end of $0 which should not have happened. Recommend checking $SHORTURL and $HTACCESS manually."

#
#EOF
