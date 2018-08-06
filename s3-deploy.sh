#!/bin/bash

# LOG MESSAGES
ERR=`echo $(tput setaf 9)ERROR:$(tput sgr 0)`
INF=`echo $(tput setaf 3)INFO:$(tput sgr 0)`
USE=`echo $(tput setaf 6)USAGE:$(tput sgr 0)`
SUCCESS=`echo $(tput setaf 2)DEPLOYMENT COMPLETE$(tput sgr 0)`
FAILURE=`echo $(tput setaf 9)DEPLOYMENT FAILED$(tput sgr 0)`
USAGE="$USE $0 -b|--bucket BUCKET -d|--directory LOCAL-DIRECTORY -i|--indexfile INDEX-FILE -p|--profile AWS-PROFILE"

# PARSE ARGUMENTS
while [[ $# -gt 0 ]]
do  key="$1"
    case $key in
        -b|--bucket)
        BUCKET="$2"
        shift && shift
        ;;
        -d|--directory)
        DIRECTORY="$2"
        shift && shift
        ;;
        -i|--indexfile)
        INDEXFILE="$2"
        shift && shift
        ;;
        -p|--profile)
        PROFILE="$2"
        shift && shift
        ;;
        *)
        echo "$ERR Invalid argument $key"
        echo "$USAGE"
        exit 1
        ;;
    esac
done

# AWS CLI
[[ -z `which aws` ]] &&
    echo "$ERR AWS CLI is not installed" &&
    echo "$INF To install AWS CLI, visit: https://amzn.to/UWz3ON" &&
    echo "$FAILURE" && exit 1

# VALIDATE ARGUMENTS
[[ -z $PROFILE ]] &&
    echo "$INF Profile not specified, setting profile to: default" &&
    PROFILE="default"
[[ $(aws configure --profile $PROFILE list 2>&1) && $? -ne 0 ]] &&
    echo "$ERR The specified profile ($PROFILE) could not be found" &&
    echo "$FAILURE" && exit 1
[[ -z $DIRECTORY ]] &&
    echo "$INF Directory not specified, seting directory to: ." &&
    DIRECTORY="."
[[ ! -d $DIRECTORY ]] &&
    echo "$ERR The specified directory ($DIRECTORY) could not be found" &&
	echo "$FAILURE" && exit 1
[[ -z $INDEXFILE ]] &&
    echo "$INF Index file not specified, seting index file to: index.html" &&
    INDEXFILE="index.html"
[[ ! -f "$DIRECTORY/$INDEXFILE" ]] &&
    echo "$ERR The specified index file ($INDEXFILE) could not be found" &&
	echo "$FAILURE" && exit 1
[[ -z $BUCKET ]] &&
    echo "$ERR Bucket not specified" &&
    echo "$FAILURE" && exit 1
[[ ! $(aws s3 ls --profile $PROFILE | grep $BUCKET) ]] &&
    echo "$ERR The specified bucket ($BUCKET) does not exist" &&
    echo "$FAILURE" && exit 1
REGION=`aws s3api get-bucket-location --bucket $BUCKET --profile $PROFILE --output text`
[[ $REGION -eq "None" ]] && REGION="us-east-1"


# DEPLOY CONTENT
echo "$INF DELETING OLD FILES"
aws s3 rm --recursive s3://$BUCKET --region $REGION --profile $PROFILE
echo "$INF UPLOADING NEW FILES"
aws s3 cp --recursive $DIRECTORY s3://$BUCKET --grants read=uri=http://acs.amazonaws.com/groups/global/AllUsers --region $REGION --profile $PROFILE
echo "$INF CONFIGURING BUCKET"
aws s3api put-bucket-acl --bucket $BUCKET --grant-read uri=http://acs.amazonaws.com/groups/global/AllUsers --region $REGION --profile $PROFILE
aws s3 website s3://$BUCKET --index-document ${INDEXFILE##*/} --region $REGION --profile $PROFILE
echo "$SUCCESS"
