#!/bin/bash

# LOG MESSAGES
ERR=`echo $(tput setaf 1)ERR:(tput sgr 0):`
INF=`echo $(tput setaf 3)INF:(tput sgr 0):`

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
        echo "$ERR Invalid argument $key."
        exit 1
        ;;
    esac
done

# AWS CLI
[[ -z `which aws` ]] &&
    echo "$ERR AWS CLI is not installed." &&
    echo "$INF To install AWS CLI, visit: https://amzn.to/UWz3ON" &&
    exit 1

# VALIDATE ARGUMENTS
[[ -z $PROFILE ]] &&
    echo "$INF Profile not specified, setting profile to: default"
    PROFILE="default"
[[ $(aws configure --profile $PROFILE list 2>&1) && $? -ne 0 ]] &&
    echo "$ERR The specified profile ($PROFILE) could not be found." &&
    exit 1
[[ -z $BUCKET ]] &&
    echo "$ERR You must specify an S3 bucket." &&
    exit 1
[[ $(aws s3api head-bucket --bucket $BUCKET --profile $PROFILE 2>&1) && $? -ne 0 ]] &&
    echo "$ERR Bucket either does not exist, or bucket access is denied." &&
    echo "$INF To list all buckets, execute: aws s3 ls" &&
    exit 1
[[ -z $DIRECTORY ]] &&
    echo "$INF Directory not specified, seting directory to: dist" &&
    DIRECTORY="dist"
[[ ! -d $DIRECTORY ]] &&
    echo "$ERR The specified directory ($DIRECTORY) could not be found." &&
	exit 1
[[ -z $INDEXFILE ]] &&
    echo "$INF Index file not specified, seting directory to: index.html" &&
    INDEXFILE="index.html"
[[ ! -f "$DIRECTORY/$INDEXFILE" ]] &&
    echo "$ERR The specified index file ($INDEXFILE) could not be found." &&
	exit 1
REGION=`aws s3api get-bucket-location --bucket $BUCKET --profile $PROFILE --output text`
[[ $REGION -eq "None" ]] && REGION="us-east-1"

# DEPLOY CONTENT
echo "$(tput setaf 3)DELETING OLD FILES...$(tput sgr 0)"
aws s3 rm --recursive s3://$BUCKET --region $REGION --profile $PROFILE
echo "$(tput setaf 3)UPLOADING NEW FILES...$(tput sgr 0)"
aws s3 cp --recursive $DIRECTORY s3://$BUCKET --grants read=uri=http://acs.amazonaws.com/groups/global/AllUsers --region $REGION --profile $PROFILE
echo "$(tput setaf 3)CONFIGURING BUCKET...$(tput sgr 0)"
aws s3api put-bucket-acl --bucket $BUCKET --grant-read uri=http://acs.amazonaws.com/groups/global/AllUsers --region $REGION --profile $PROFILE
aws s3 website s3://$BUCKET --index-document ${INDEXFILE##*/} --region $REGION --profile $PROFILE
echo "$(tput setaf 2)DEPLOY COMPLETE$(tput sgr 0)"
