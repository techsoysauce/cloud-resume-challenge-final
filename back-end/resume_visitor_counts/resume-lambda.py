import boto3
from decimal import Decimal


# Connecting to DynamoDB table
dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table('jp_resume_db')

# Define paths used in API for GET and POST
get_count_path = "/jp_resume_lambda_stage/get_counts"
add_count_path = "/jp_resume_lambda_stage/add_count"

# Lambda to get total visits or add a visit
def lambda_handler(event, context):
    # Grab the current visitor count and store in a variable
    response = table.get_item(Key={
            'record_id':'0'
        })
    visitor_counts = int(response['Item']['record_count'])
    # DEBUG CODE--> print(f"Visitor count is: {visitor_counts}")
    print(event)
    
    # Grab total visits for GET request
    if event['rawPath'] == get_count_path:
        # DEBUG CODE--> print("Getting total visits")

        return visitor_counts


    # Add 1 to total visits for POST request and return new visits value
    elif event['rawPath'] == add_count_path:
        # DEBUG CODE--> print("Adding a count")
        
        visitor_counts += 1
        response = table.update_item(
        Key={
            'record_id':'0'
        },
        UpdateExpression="set record_count=:r",
        ExpressionAttributeValues={
            ':r': Decimal(visitor_counts)
        }
        )

        return visitor_counts
