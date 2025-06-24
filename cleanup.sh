#!/bin/bash

# Sketch to Video POC Cleanup Script
set -e

PROJECT_NAME="sketch-video-poc"
REGION="us-east-1"
STACK_NAME="${PROJECT_NAME}-stack"

echo "🧹 Starting cleanup of Sketch to Video POC resources..."

# Check if stack exists
if ! aws cloudformation describe-stacks --stack-name $STACK_NAME --region $REGION > /dev/null 2>&1; then
    echo "❌ Stack $STACK_NAME does not exist in region $REGION"
    exit 1
fi

# Get bucket names before deleting stack
echo "📋 Getting resource information..."
WEBSITE_BUCKET=$(aws cloudformation describe-stacks \
    --stack-name $STACK_NAME \
    --region $REGION \
    --query 'Stacks[0].Outputs[?OutputKey==`WebsiteBucketName`].OutputValue' \
    --output text 2>/dev/null || echo "")

MEDIA_BUCKET=$(aws cloudformation describe-stacks \
    --stack-name $STACK_NAME \
    --region $REGION \
    --query 'Stacks[0].Outputs[?OutputKey==`MediaBucketName`].OutputValue' \
    --output text 2>/dev/null || echo "")

# Empty S3 buckets
if [ -n "$WEBSITE_BUCKET" ]; then
    echo "🗑️  Emptying website bucket: $WEBSITE_BUCKET"
    aws s3 rm s3://$WEBSITE_BUCKET --recursive --region $REGION 2>/dev/null || true
fi

if [ -n "$MEDIA_BUCKET" ]; then
    echo "🗑️  Emptying media bucket: $MEDIA_BUCKET"
    aws s3 rm s3://$MEDIA_BUCKET --recursive --region $REGION 2>/dev/null || true
    
    # Also remove versioned objects
    echo "🗑️  Removing versioned objects from media bucket..."
    aws s3api list-object-versions \
        --bucket $MEDIA_BUCKET \
        --region $REGION \
        --query 'Versions[].{Key:Key,VersionId:VersionId}' \
        --output text | while read key version; do
        if [ -n "$key" ] && [ -n "$version" ]; then
            aws s3api delete-object \
                --bucket $MEDIA_BUCKET \
                --key "$key" \
                --version-id "$version" \
                --region $REGION 2>/dev/null || true
        fi
    done
    
    # Remove delete markers
    aws s3api list-object-versions \
        --bucket $MEDIA_BUCKET \
        --region $REGION \
        --query 'DeleteMarkers[].{Key:Key,VersionId:VersionId}' \
        --output text | while read key version; do
        if [ -n "$key" ] && [ -n "$version" ]; then
            aws s3api delete-object \
                --bucket $MEDIA_BUCKET \
                --key "$key" \
                --version-id "$version" \
                --region $REGION 2>/dev/null || true
        fi
    done
fi

# Delete CloudFormation stack
echo "🗑️  Deleting CloudFormation stack: $STACK_NAME"
aws cloudformation delete-stack \
    --stack-name $STACK_NAME \
    --region $REGION

echo "⏳ Waiting for stack deletion to complete..."
aws cloudformation wait stack-delete-complete \
    --stack-name $STACK_NAME \
    --region $REGION

if [ $? -eq 0 ]; then
    echo "✅ Stack deleted successfully"
else
    echo "❌ Stack deletion failed or timed out"
    echo "Please check the AWS Console for more details"
    exit 1
fi

echo ""
echo "🎉 Cleanup completed successfully!"
echo ""
echo "📋 Cleanup Summary:"
echo "   • Stack Name: $STACK_NAME"
echo "   • Region: $REGION"
echo "   • Website Bucket: $WEBSITE_BUCKET (deleted)"
echo "   • Media Bucket: $MEDIA_BUCKET (deleted)"
echo ""
echo "All resources have been removed from your AWS account."
echo ""
