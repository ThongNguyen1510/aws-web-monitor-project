import urllib.request
import urllib.error
import boto3
import time
import os
import json
from datetime import datetime

DYNAMODB_TABLE = os.environ['DYNAMODB_TABLE']
SNS_TOPIC_ARN = os.environ['SNS_TOPIC_ARN']
TARGET_URLS = json.loads(os.environ['TARGET_URLS'])

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table(DYNAMODB_TABLE)
sns = boto3.client('sns')

def check_url(url):
    timestamp = datetime.utcnow().isoformat()
    status_code = 0
    is_up = False
    start_time = time.time()
    
    try:
        req = urllib.request.Request(url, method='GET')
        # Thêm header User-Agent để tránh bị block bởi một số server
        req.add_header('User-Agent', 'AWS-Monitor/1.0')
        with urllib.request.urlopen(req, timeout=5) as response:
            status_code = response.getcode()
            is_up = (status_code == 200)
    except urllib.error.HTTPError as e:
        status_code = e.code
    except Exception as e:
        status_code = -1 # Lỗi mạng, timeout
        
    response_time_ms = int((time.time() - start_time) * 1000)
    
    # Ghi vào DynamoDB
    table.put_item(
        Item={
            'url': url,
            'timestamp': timestamp,
            'status_code': status_code,
            'response_time_ms': response_time_ms,
            'is_up': is_up
        }
    )
    
    # Gửi cảnh báo
    if not is_up:
        message = f"CẢNH BÁO: Website {url} đang gặp sự cố!\nThời gian: {timestamp}\nStatus Code: {status_code}\nResponse Time: {response_time_ms} ms."
        sns.publish(
            TopicArn=SNS_TOPIC_ARN,
            Subject=f"ALERT: Website Down ({url})",
            Message=message
        )
    return is_up

def lambda_handler(event, context):
    results = {}
    for url in TARGET_URLS:
        results[url] = check_url(url)
        
    return {
        'statusCode': 200,
        'body': json.dumps({'message': 'Checks completed', 'results': results})
    }
