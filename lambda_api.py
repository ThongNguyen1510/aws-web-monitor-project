import boto3
import os
import json
from decimal import Decimal

DYNAMODB_TABLE = os.environ['DYNAMODB_TABLE']
dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table(DYNAMODB_TABLE)

# DynamoDB trả về số dưới dạng Decimal, json mặc định không hiểu
class DecimalEncoder(json.JSONEncoder):
    def default(self, obj):
        if isinstance(obj, Decimal):
            return int(obj)
        return super(DecimalEncoder, self).default(obj)

def lambda_handler(event, context):
    try:
        # Scan toàn bộ table (Với demo nhỏ thì scan ổn, thực tế dùng Query index)
        response = table.scan()
        items = response.get('Items', [])
        
        # Nhóm dữ liệu: Lấy trạng thái mới nhất của từng URL
        latest_status = {}
        for item in items:
            url = item['url']
            ts = item['timestamp']
            if url not in latest_status or ts > latest_status[url]['timestamp']:
                latest_status[url] = item
                
        # Lấy lịch sử 10 lần ping gần nhất cho mỗi URL
        history = {}
        for item in items:
            url = item['url']
            if url not in history:
                history[url] = []
            history[url].append(item)
            
        for url in history:
            # Sort theo thời gian giảm dần và lấy 10 bản ghi
            history[url] = sorted(history[url], key=lambda x: x['timestamp'], reverse=True)[:10]

        return {
            'statusCode': 200,
            'headers': {
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Headers': 'Content-Type',
                'Access-Control-Allow-Methods': 'OPTIONS,GET'
            },
            'body': json.dumps({
                'latest': list(latest_status.values()),
                'history': history
            }, cls=DecimalEncoder)
        }
    except Exception as e:
        return {
            'statusCode': 500,
            'headers': {
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps({'error': str(e)})
        }
