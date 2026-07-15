import urllib.request
import urllib.error
import boto3
import time
import os
from datetime import datetime

DYNAMODB_TABLE = os.environ['DYNAMODB_TABLE']
SNS_TOPIC_ARN = os.environ['SNS_TOPIC_ARN']
TARGET_URL = os.environ['TARGET_URL']

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table(DYNAMODB_TABLE)
sns = boto3.client('sns')

def lambda_handler(event, context):
    timestamp = datetime.utcnow().isoformat()
    status_code = 0
    is_up = False
    
    start_time = time.time()
    try:
        req = urllib.request.Request(TARGET_URL, method='GET')
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
            'url': TARGET_URL,
            'timestamp': timestamp,
            'status_code': status_code,
            'response_time_ms': response_time_ms,
            'is_up': is_up
        }
    )
    
    # Gửi cảnh báo
    if not is_up:
        message = f"CẢNH BÁO: Website {TARGET_URL} đang gặp sự cố!\nThời gian: {timestamp}\nStatus Code: {status_code}\nResponse Time: {response_time_ms} ms."
        sns.publish(
            TopicArn=SNS_TOPIC_ARN,
            Subject=f"ALERT: Website Down ({TARGET_URL})",
            Message=message
        )
        
    return {'statusCode': 200, 'body': f'Checked {TARGET_URL} - Status: {status_code}'}
