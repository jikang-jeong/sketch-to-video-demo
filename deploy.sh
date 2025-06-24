#!/bin/bash

# Sketch to Video POC Deployment Script
set -e

PROJECT_NAME="sketch-video-poc"
REGION="us-east-1"
STACK_NAME="${PROJECT_NAME}-stack"

echo "🚀 Starting deployment of Sketch to Video POC..."

# Check if AWS CLI is configured
if ! aws sts get-caller-identity > /dev/null 2>&1; then
    echo "❌ AWS CLI is not configured. Please run 'aws configure' first."
    exit 1
fi

echo "✅ AWS CLI is configured"

# Deploy CloudFormation stack
echo "📦 Deploying CloudFormation stack..."
aws cloudformation deploy \
    --template-file cloudformation/infrastructure.yaml \
    --stack-name $STACK_NAME \
    --parameter-overrides ProjectName=$PROJECT_NAME \
    --capabilities CAPABILITY_NAMED_IAM \
    --region $REGION

if [ $? -ne 0 ]; then
    echo "❌ CloudFormation deployment failed"
    exit 1
fi

echo "✅ CloudFormation stack deployed successfully"

# Get stack outputs
echo "📋 Getting stack outputs..."
API_URL=$(aws cloudformation describe-stacks \
    --stack-name $STACK_NAME \
    --region $REGION \
    --query 'Stacks[0].Outputs[?OutputKey==`ApiGatewayUrl`].OutputValue' \
    --output text)

CLOUDFRONT_URL=$(aws cloudformation describe-stacks \
    --stack-name $STACK_NAME \
    --region $REGION \
    --query 'Stacks[0].Outputs[?OutputKey==`CloudFrontUrl`].OutputValue' \
    --output text)

WEBSITE_BUCKET=$(aws cloudformation describe-stacks \
    --stack-name $STACK_NAME \
    --region $REGION \
    --query 'Stacks[0].Outputs[?OutputKey==`WebsiteBucketName`].OutputValue' \
    --output text)

MEDIA_BUCKET=$(aws cloudformation describe-stacks \
    --stack-name $STACK_NAME \
    --region $REGION \
    --query 'Stacks[0].Outputs[?OutputKey==`MediaBucketName`].OutputValue' \
    --output text)

echo "API Gateway URL: $API_URL"
echo "CloudFront URL: $CLOUDFRONT_URL"
echo "Website Bucket: $WEBSITE_BUCKET"
echo "Media Bucket: $MEDIA_BUCKET"

# Verify S3 buckets are NOT public
echo "🔒 Verifying S3 bucket security..."

# Check Media Bucket
MEDIA_PUBLIC_ACCESS=$(aws s3api get-public-access-block \
    --bucket $MEDIA_BUCKET \
    --region $REGION \
    --query 'PublicAccessBlockConfiguration.RestrictPublicBuckets' \
    --output text)

if [ "$MEDIA_PUBLIC_ACCESS" != "True" ]; then
    echo "❌ WARNING: Media bucket may have public access enabled!"
    exit 1
fi

# Check Website Bucket
WEBSITE_PUBLIC_ACCESS=$(aws s3api get-public-access-block \
    --bucket $WEBSITE_BUCKET \
    --region $REGION \
    --query 'PublicAccessBlockConfiguration.RestrictPublicBuckets' \
    --output text)

if [ "$WEBSITE_PUBLIC_ACCESS" != "True" ]; then
    echo "❌ WARNING: Website bucket may have public access enabled!"
    exit 1
fi

echo "✅ S3 buckets are properly secured (no public access)"

# Update frontend with API URL
echo "🔧 Updating frontend configuration..."
sed "s|API_GATEWAY_URL_PLACEHOLDER|$API_URL|g" frontend/index.html > frontend/index_updated.html
mv frontend/index_updated.html frontend/index.html

# Upload website to S3
echo "📤 Uploading website to S3..."
aws s3 sync frontend/ s3://$WEBSITE_BUCKET/ \
    --region $REGION \
    --delete

if [ $? -ne 0 ]; then
    echo "❌ Website upload failed"
    exit 1
fi

echo "✅ Website uploaded successfully"

# Get CloudFront distribution ID and invalidate cache
echo "🔄 Invalidating CloudFront cache..."
DISTRIBUTION_ID=$(aws cloudfront list-distributions \
    --query "DistributionList.Items[?Origins.Items[0].DomainName=='$WEBSITE_BUCKET.s3.$REGION.amazonaws.com'].Id" \
    --output text)

if [ -n "$DISTRIBUTION_ID" ]; then
    aws cloudfront create-invalidation \
        --distribution-id $DISTRIBUTION_ID \
        --paths "/*" > /dev/null
    echo "✅ CloudFront cache invalidated"
else
    echo "⚠️  Could not find CloudFront distribution for cache invalidation"
fi

echo ""
echo "🎉 Deployment completed successfully!"
echo ""
echo "📋 Deployment Summary:"
echo "   • Stack Name: $STACK_NAME"
echo "   • Region: $REGION"
echo "   • API Gateway URL: $API_URL"
echo "   • Website URL: $CLOUDFRONT_URL"
echo "   • Media Bucket: $MEDIA_BUCKET (🔒 Private)"
echo "   • Website Bucket: $WEBSITE_BUCKET (🔒 Private)"
echo ""
echo "🌐 Access your application at: $CLOUDFRONT_URL"
echo ""
echo "⚠️  Note: CloudFront distribution may take 10-15 minutes to fully deploy."
echo "   If the website doesn't load immediately, please wait a few minutes."
echo ""
