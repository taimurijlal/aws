import json
import boto3

# Initialize AWS clients
s3_client = boto3.client('s3')
sns_client = boto3.client('sns')
bedrock_client = boto3.client("bedrock-runtime", region_name="us-east-1")

# Set the model ID for Bedrock
model_id = "anthropic.claude-3-haiku-20240307-v1:0"

def lambda_handler(event, context):
    # Extract the bucket name and object key from the EventBridge event
    detail = event['detail']
    bucket_name = detail['requestParameters']['bucketName']
    object_key = detail['requestParameters'].get('key', 'Unknown')  # Adjust if needed based on the event structure

    # Get the object from S3
    try:
        s3_response = s3_client.get_object(Bucket=bucket_name, Key=object_key)
        file_content = s3_response['Body'].read().decode('utf-8')
    except Exception as e:
        print(f"Error reading object {object_key} from bucket {bucket_name}. Error: {str(e)}")
        file_content = f"Error reading object {object_key} from bucket {bucket_name}. Error: {str(e)}"
    
    # Define the prompt for the Bedrock model
    prompt = (
        f"As an expert in log file analysis, analyze the following log file. "
        f"Summarize what the user did in the session and identify any suspicious activity "
        f"that might need to be checked:\n\n{file_content}"
    )
    
    # Format the request payload for the Bedrock model
    native_request = {
        "anthropic_version": "bedrock-2023-05-31",
        "max_tokens": 512,
        "temperature": 0.5,
        "messages": [
            {
                "role": "user",
                "content": [{"type": "text", "text": prompt}],
            }
        ],
    }

    # Convert the native request to JSON
    request = json.dumps(native_request)

    # Invoke the Bedrock model with the request
    try:
        response = bedrock_client.invoke_model(modelId=model_id, body=request)
        model_response = json.loads(response["body"].read())
        response_text = model_response["content"][0]["text"]
    except Exception as e:
        print(f"Error invoking Bedrock model. Error: {str(e)}")
        response_text = f"Error invoking Bedrock model. Error: {str(e)}"
    
    # Construct the SNS message
    message = f"An log file with key '{object_key}' was uploaded to the S3 bucket '{bucket_name}'.\n\n"
    message += "Bedrock model response:\n"
    message += response_text
    subject = "Session Manager Log File Analysis by Amazon Bedrock"

    # Publish the message to the SNS topic
    try:
        sns_response = sns_client.publish(
            TopicArn='arn:aws:sns:us-east-1:533267053787:Bedrock-POC',  # Correct SNS topic ARN
            Message=message,
            Subject=subject
        )
        print("Notification sent successfully!")
    except Exception as e:
        print(f"Error publishing to SNS topic. Error: {str(e)}")
    
    return {
        'statusCode': 200,
        'body': json.dumps('Function executed successfully!')
    }
