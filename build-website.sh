#!/usr/bin/env bash

#Configure Git User
git config --global user.name "${GITHUB_ACTOR}"
git config --global user.email "${GITHUB_ACTOR}@users.noreply.github.com"

#Set Environment Variables
TESTING=false
VERSION_NUMBER=dev
while getopts "t:v:" arg; do
  case "$arg" in
    t)
      TESTING=$OPTARG
      ;;
    v)
      VERSION_NUMBER=$OPTARG
      ;;
  esac
done 
echo "TESTING set to $TESTING."

#Create and Sync gh-pages for Mike 
git checkout -b docs-update
git branch gh-pages 
mike delete --all 
git checkout gh-pages 
cd.. 

#ADD PARAMETER CHECKING
if [ "$TESTING" = "true" ]; then 
  aws s3 mv s3://updated-documentation-website/website/index.html . 
  aws s3 mv s3://updated-documentation-website/website/versions.json . 
else
  aws s3 mv s3://djl-ai/documentation/nightly/index.html .
  aws s3 mv s3://djl-ai/documentation/nightly/versions.json . 
fi 

#TEST REMOVING THIS 
git add . 
git commit -m "Sync Finished" 
git checkout docs-update
cd docs

echo "deploying $VERSION_NUMBER"
if [ "$VERSION_NUMBER" != "master" ]; then
  mike deploy $VERSION_NUMBER 
  mike set-default $VERSION_NUMBER 
else
  mike deploy dev 
  mike set-default dev
fi

#Upload New Artificats
git checkout gh-pages
cd .. 
echo "Syncing..."
if [ "$TESTING" = "true" ]; then
  aws s3 cp ./index.html s3://updated-documentation-website/website/ 
  aws s3 cp ./versions.json s3://updated-documentation-website/website/ 
  aws s3 sync ./"$VERSION_NUMBER" s3://updated-documentation-website/website/ 
else
  aws s3 cp ./index.html s3://djl-ai/documentation/nightly 
  aws s3 cp ./versions.json s3://djl-ai/documentation/nightly 
  aws s3 sync ./"$VERSION_NUMBER" s3://djl-ai/documentation/nightly 
  aws cloudfront create-invalidation --distribution-id E733IIDCG0G5U --paths "/*"
fi
