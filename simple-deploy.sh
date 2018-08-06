#!/bin/bash

# ARGUMENTS
BUCKET=$1
DIRECTORY=${2:-"dist"}
INDEXFILE=${3:-"index.html"}

# MESSAGES
ERR=`echo $(tput setaf 1)ERR:$(tput sgr 0)`
INF=`echo $(tput setaf 3)INF:$(tput sgr 0)`
USE=`echo $(tput setaf 6)USE:$(tput sgr 0)`

# VALIDATE ARGUMENTS
if [ "$#" -lt 1 -o "$#" -gt 3 ]
then echo "$ERR Incorrect number of arguments."
     echo "$USE $0 [bucket-name] [directory-name] [index-file]"
     echo "     * $(tput bold)bucket-name$(tput sgr 0) ($(tput sitm)mandatory$(tput sgr 0)):"
     echo "       an S3 bucket with an optional /folder path where files will be deployed"
     echo "       example: mybucket/folder1/test"
     echo "     * $(tput bold)directory-name$(tput sgr 0) ($(tput sitm)optional$(tput sgr 0)):"
     echo "       a local directory where app files are stored"
     echo "       default value: ./dist"
     echo "     * $(tput bold)index-filename$(tput sgr 0) ($(tput sitm)conditional$(tput sgr 0)):"
     echo "       a file inside the local directory that will be served as a landing page"
     echo "       default value: index.html"
     exit 1
elif [ ! -d "$DIRECTORY" ]
then echo "$ERR '${DIRECTORY}' is not a directory."
	 exit 1
elif [ ! -e "$INDEXFILE" -a ! -e "$DIRECTORY/$INDEXFILE" ]
then echo "$ERR Unable to locate file '${DIRECTORY}/${INDEXFILE}'"
     exit 1
fi

# CHECK AWS-CLI
if   [ -z `which aws` ]
then echo "$ERR AWS-CLI is not installed."
	 echo "$INF To install AWS-CLI, visit: http://docs.aws.amazon.com/cli/latest/userguide/installing.html"
	 exit 1
fi

# CHECK BUCKET
BUCKET_EXISTS=`aws s3 ls s3://${BUCKET} 2>&1 | grep -e "NoSuchBucket" -e "AllAccessDisabled"`
if   [ -n "$BUCKET_EXISTS" ]
then echo "$ERR Bucket either does not exist, or bucket access is denied."
	 echo "$INF To list all buckets, enter: aws s3 ls"
	 exit 1
fi

# DEPLOY APP
REGION=`aws s3api get-bucket-location --bucket ${BUCKET%%/*} --output text`
echo "$(tput setaf 3)DELETING OLD FILES...$(tput sgr 0)"
aws s3 rm --recursive s3://${BUCKET} --region ${REGION}
echo "$(tput setaf 3)UPLOADING NEW FILES...$(tput sgr 0)"
aws s3 cp --recursive ${DIRECTORY} s3://${BUCKET} --grants read=uri=http://acs.amazonaws.com/groups/global/AllUsers --region ${REGION}
echo "$(tput setaf 3)CONFIGURING BUCKET...$(tput sgr 0)"
aws s3api put-bucket-acl --bucket ${BUCKET%%/*} --grant-read uri=http://acs.amazonaws.com/groups/global/AllUsers --region ${REGION}
aws s3 website s3://${BUCKET%%/*} --index-document ${INDEXFILE##*/} --region ${REGION}
echo "$(tput setaf 2)DEPLOY COMPLETE$(tput sgr 0)"
