import json
import boto3
import base64
import os

s3 = boto3.client('s3')
bedrock = boto3.client('bedrock-runtime', region_name='us-east-1')

def lambda_handler(event, context):
    try:
        print(f"Received event: {json.dumps(event)}")
        
        body = json.loads(event['body'])
        key = body['key']
        user_text = body.get('userText', '')
        
        print(f"Processing key: {key}, user_text: {user_text}")
        
        bucket_name = os.environ['BUCKET_NAME']
        
        # Get image from S3
        try:
            response = s3.get_object(Bucket=bucket_name, Key=key)
            image_data = response['Body'].read()
            image_base64 = base64.b64encode(image_data).decode('utf-8')
            print(f"Successfully retrieved image from S3, size: {len(image_data)} bytes")
        except Exception as e:
            print(f"Error retrieving image from S3: {str(e)}")
            raise e
        
        # Analyze image with Claude
        prompt = """이 이미지를 자세히 분석해주세요. 다음 내용을 포함해서 설명해주세요:
        1. 이미지에 그려진 주요 객체나 인물
        2. 배경과 환경
        3. 색상과 스타일
        4. 전체적인 분위기나 느낌
        5. 영상 제작에 활용할 수 있는 특징들
        
        분석 결과를 한국어로 자세하게 설명해주세요."""
        
        message = {
            "messages": [
                {
                    "role": "user",
                    "content": [
                        {
                            "image": {
                                "format": "jpeg",
                                "source": {
                                    "bytes": image_base64
                                }
                            }
                        },
                        {
                            "text": prompt
                        }
                    ]
                }
            ],
            "inferenceConfig": {
                "max_new_tokens": 1000
            }
        }
        
        print("Calling Nova Pro API...")
        try:
            response = bedrock.invoke_model(
                modelId='amazon.nova-pro-v1:0',
                body=json.dumps(message)
            )
            
            result = json.loads(response['body'].read())
            analysis = result['output']['message']['content'][0]['text']
            print(f"Nova Pro analysis completed, length: {len(analysis)}")
        except Exception as e:
            print(f"Error calling Nova Pro API: {str(e)}")
            raise e
        
        # Generate video prompt
        video_prompt = generate_video_prompt(analysis, user_text)
        print(f"Generated video prompt, length: {len(video_prompt)}")
        
        return {
            'statusCode': 200,
            'headers': {
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Headers': 'Content-Type',
                'Access-Control-Allow-Methods': 'POST, OPTIONS'
            },
            'body': json.dumps({
                'analysis': analysis,
                'videoPrompt': video_prompt
            })
        }
    except Exception as e:
        print(f"Error in lambda_handler: {str(e)}")
        return {
            'statusCode': 500,
            'headers': {
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps({'error': str(e)})
        }

def generate_video_prompt(analysis, user_text):
    """
    Nova Pro를 사용해서 영상 생성 프롬프트를 생성하는 함수 (Nova Reel 1.1용 30초 영상)
    """
    # Nova Pro에게 보낼 개선된 프롬프트 구성
    nova_prompt = f"""Based on this image analysis: "{analysis}"
And user request: "{user_text}"

Create a detailed 30-second video prompt for Amazon Nova Reel 1.1 MULTI_SHOT_AUTOMATED mode.

Focus on the SPECIFIC content from the image and user request. Don't just list technical requirements.

Create a vivid, detailed description that includes:

1. SPECIFIC SCENES based on the image content and user request
2. Detailed camera movements that enhance the story
3. Lighting that matches the mood and setting
4. Colors and visual style appropriate for the content
5. Environmental details that bring the scene to life
6. Smooth transitions between different shots
7. Professional cinematic quality (8K, 24fps)

Write a comprehensive video prompt that tells a complete visual story. Be specific about what happens in each scene, how the camera moves, what the lighting looks like, and how it all connects together.

Write in English and focus on creating engaging, specific visual content rather than just listing technical terms."""

    # Nova Pro API 호출을 위한 메시지 구성
    message = {
        "messages": [
            {
                "role": "user",
                "content": [
                    {
                        "text": nova_prompt
                    }
                ]
            }
        ],
        "inferenceConfig": {
            "max_new_tokens": 2500
        }
    }
    
    print("Calling Nova Pro API for video prompt generation...")
    response = bedrock.invoke_model(
        modelId='amazon.nova-pro-v1:0',
        body=json.dumps(message)
    )
    
    result = json.loads(response['body'].read())
    generated_prompt = result['output']['message']['content'][0]['text'].strip()
    
    print(f"Nova Pro generated prompt length: {len(generated_prompt)}")
    
    # 최대 길이 제한만 유지
    if len(generated_prompt) > 3500:
        generated_prompt = generated_prompt[:3497] + "..."
        print(f"Trimmed prompt to: {len(generated_prompt)} characters")
    
    print(f"Final prompt length: {len(generated_prompt)}")
    return generated_prompt
