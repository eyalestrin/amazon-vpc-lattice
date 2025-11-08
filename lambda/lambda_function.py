import json
import os
import boto3
import psycopg2
from psycopg2.extras import RealDictCursor
import re

def lambda_handler(event, context):
    try:
        # Parse request
        http_method = event.get('requestContext', {}).get('http', {}).get('method', 'GET')
        path = event.get('requestContext', {}).get('http', {}).get('path', '/')
        
        # Serve web interface for browser requests
        if http_method == 'GET' and 'text/html' in event.get('headers', {}).get('accept', ''):
            return serve_web_interface(event)
        
        # Get database credentials from Secrets Manager
        db_credentials = get_db_credentials()
        
        if http_method == 'GET':
            return handle_get_request(event, db_credentials)
        elif http_method == 'POST':
            return handle_post_request(event, db_credentials)
        else:
            return {
                'statusCode': 405,
                'headers': {'Content-Type': 'application/json'},
                'body': json.dumps({'error': 'Method not allowed'})
            }
            
    except Exception as e:
        return {
            'statusCode': 500,
            'headers': {'Content-Type': 'application/json'},
            'body': json.dumps({'error': str(e)})
        }

def get_db_credentials():
    """Retrieve database credentials from AWS Secrets Manager"""
    secret_arn = os.environ['RDS_SECRET_ARN']
    region = os.environ['AWS_REGION']
    
    client = boto3.client('secretsmanager', region_name=region)
    response = client.get_secret_value(SecretId=secret_arn)
    secret = json.loads(response['SecretString'])
    
    return {
        'host': secret['host'],
        'port': secret['port'],
        'database': secret['dbname'],
        'user': secret['username'],
        'password': secret['password']
    }

def serve_web_interface(event):
    """Serve HTML interface for browser requests"""
    query_params = event.get('queryStringParameters') or {}
    transaction_id = query_params.get('id')
    
    if transaction_id:
        # Validate transaction ID
        if not validate_transaction_id(transaction_id):
            error_msg = "Invalid Transaction ID. Please enter a positive integer (1-999999)."
            return {
                'statusCode': 400,
                'headers': {'Content-Type': 'text/html'},
                'body': get_html_form(error_msg)
            }
        
        # Get transaction data
        try:
            db_credentials = get_db_credentials()
            with psycopg2.connect(**db_credentials) as conn:
                with conn.cursor(cursor_factory=RealDictCursor) as cur:
                    cur.execute("SELECT * FROM transactions WHERE id = %s", (transaction_id,))
                    result = cur.fetchone()
                    
                    if result:
                        transaction_html = f"""
                        <div class="result">
                            <h3>Transaction Details</h3>
                            <p><strong>ID:</strong> {result['id']}</p>
                            <p><strong>Customer ID:</strong> {result['customer_id']}</p>
                            <p><strong>Product:</strong> {result['product_name']}</p>
                            <p><strong>Amount:</strong> ${result['amount']}</p>
                            <p><strong>Date:</strong> {result['transaction_date']}</p>
                        </div>
                        """
                        return {
                            'statusCode': 200,
                            'headers': {'Content-Type': 'text/html'},
                            'body': get_html_form(transaction_html=transaction_html)
                        }
                    else:
                        error_msg = f"Transaction ID {transaction_id} not found."
                        return {
                            'statusCode': 404,
                            'headers': {'Content-Type': 'text/html'},
                            'body': get_html_form(error_msg)
                        }
        except Exception as e:
            error_msg = f"Database error: {str(e)}"
            return {
                'statusCode': 500,
                'headers': {'Content-Type': 'text/html'},
                'body': get_html_form(error_msg)
            }
    
    # Show form
    return {
        'statusCode': 200,
        'headers': {'Content-Type': 'text/html'},
        'body': get_html_form()
    }

def validate_transaction_id(transaction_id):
    """Validate transaction ID according to SQL schema (SERIAL PRIMARY KEY)"""
    if not transaction_id:
        return False
    
    # Check if it's a positive integer
    if not re.match(r'^[1-9]\d*$', str(transaction_id)):
        return False
    
    # Check reasonable range (1 to 999999)
    try:
        id_int = int(transaction_id)
        return 1 <= id_int <= 999999
    except ValueError:
        return False

def get_html_form(error_msg=None, transaction_html=None):
    """Generate HTML form for transaction lookup"""
    error_display = f'<div class="error">{error_msg}</div>' if error_msg else ''
    transaction_display = transaction_html if transaction_html else ''
    
    return f"""
    <!DOCTYPE html>
    <html>
    <head>
        <title>Transaction Lookup - AWS VPC Lattice Demo</title>
        <style>
            body {{ font-family: Arial, sans-serif; max-width: 600px; margin: 50px auto; padding: 20px; }}
            .form-group {{ margin: 20px 0; }}
            input[type="number"] {{ padding: 10px; font-size: 16px; width: 200px; }}
            button {{ padding: 10px 20px; font-size: 16px; background: #007bff; color: white; border: none; cursor: pointer; }}
            button:hover {{ background: #0056b3; }}
            .error {{ color: red; margin: 10px 0; padding: 10px; border: 1px solid red; background: #ffe6e6; }}
            .result {{ margin: 20px 0; padding: 15px; border: 1px solid #28a745; background: #e6ffe6; }}
            .info {{ margin: 20px 0; padding: 10px; background: #f8f9fa; border-left: 4px solid #007bff; }}
        </style>
    </head>
    <body>
        <h1>Transaction Lookup</h1>
        <p>Enter a Transaction ID to retrieve transaction details from the secure cross-account RDS database via AWS VPC Lattice.</p>
        
        {error_display}
        
        <form method="get">
            <div class="form-group">
                <label for="id">Transaction ID:</label><br>
                <input type="number" id="id" name="id" min="1" max="999999" placeholder="Enter ID (1-999999)" required>
                <button type="submit">Lookup Transaction</button>
            </div>
        </form>
        
        {transaction_display}
        
        <div class="info">
            <h4>Architecture:</h4>
            <p>Browser → Lambda Function URL → Lambda (Account 1) → VPC Lattice → RDS PostgreSQL (Account 2)</p>
            <p>Database credentials are securely retrieved from AWS Secrets Manager with cross-account access.</p>
        </div>
    </body>
    </html>
    """

def handle_get_request(event, db_credentials):
    """Handle API GET requests to retrieve transactions"""
    try:
        query_params = event.get('queryStringParameters') or {}
        transaction_id = query_params.get('id')
        
        with psycopg2.connect(**db_credentials) as conn:
            with conn.cursor(cursor_factory=RealDictCursor) as cur:
                if transaction_id:
                    # Validate transaction ID for API requests too
                    if not validate_transaction_id(transaction_id):
                        return {
                            'statusCode': 400,
                            'headers': {'Content-Type': 'application/json'},
                            'body': json.dumps({'error': 'Invalid transaction ID. Must be a positive integer (1-999999).'})
                        }
                    
                    # Get specific transaction
                    cur.execute("SELECT * FROM transactions WHERE id = %s", (transaction_id,))
                    result = cur.fetchone()
                    if result:
                        return {
                            'statusCode': 200,
                            'headers': {'Content-Type': 'application/json'},
                            'body': json.dumps(dict(result), default=str)
                        }
                    else:
                        return {
                            'statusCode': 404,
                            'headers': {'Content-Type': 'application/json'},
                            'body': json.dumps({'error': 'Transaction not found'})
                        }
                else:
                    # Get all transactions (limited to 100)
                    cur.execute("SELECT * FROM transactions ORDER BY transaction_date DESC LIMIT 100")
                    results = cur.fetchall()
                    return {
                        'statusCode': 200,
                        'headers': {'Content-Type': 'application/json'},
                        'body': json.dumps([dict(row) for row in results], default=str)
                    }
                    
    except Exception as e:
        return {
            'statusCode': 500,
            'headers': {'Content-Type': 'application/json'},
            'body': json.dumps({'error': f'Database error: {str(e)}'})
        }

def handle_post_request(event, db_credentials):
    """Handle POST requests to create new transactions"""
    try:
        body = json.loads(event.get('body', '{}'))
        
        required_fields = ['customer_id', 'product_name', 'amount', 'transaction_date']
        for field in required_fields:
            if field not in body:
                return {
                    'statusCode': 400,
                    'headers': {'Content-Type': 'application/json'},
                    'body': json.dumps({'error': f'Missing required field: {field}'})
                }
        
        # Validate customer_id (should be positive integer)
        try:
            customer_id = int(body['customer_id'])
            if customer_id <= 0:
                raise ValueError()
        except (ValueError, TypeError):
            return {
                'statusCode': 400,
                'headers': {'Content-Type': 'application/json'},
                'body': json.dumps({'error': 'customer_id must be a positive integer'})
            }
        
        # Validate amount (should be positive decimal)
        try:
            amount = float(body['amount'])
            if amount <= 0:
                raise ValueError()
        except (ValueError, TypeError):
            return {
                'statusCode': 400,
                'headers': {'Content-Type': 'application/json'},
                'body': json.dumps({'error': 'amount must be a positive number'})
            }
        
        with psycopg2.connect(**db_credentials) as conn:
            with conn.cursor(cursor_factory=RealDictCursor) as cur:
                # Insert new transaction
                cur.execute("""
                    INSERT INTO transactions (customer_id, product_name, amount, transaction_date)
                    VALUES (%s, %s, %s, %s)
                    RETURNING *
                """, (body['customer_id'], body['product_name'], body['amount'], body['transaction_date']))
                
                result = cur.fetchone()
                conn.commit()
                
                return {
                    'statusCode': 201,
                    'headers': {'Content-Type': 'application/json'},
                    'body': json.dumps(dict(result), default=str)
                }
                
    except json.JSONDecodeError:
        return {
            'statusCode': 400,
            'headers': {'Content-Type': 'application/json'},
            'body': json.dumps({'error': 'Invalid JSON in request body'})
        }
    except Exception as e:
        return {
            'statusCode': 500,
            'headers': {'Content-Type': 'application/json'},
            'body': json.dumps({'error': f'Database error: {str(e)}'})
        }