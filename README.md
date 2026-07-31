# AWS Uptime Monitor Dashboard

A complete Serverless Fullstack application built on AWS and managed via Terraform. 
It monitors a list of websites every 5 minutes, logs results to DynamoDB, alerts via Email (SNS) when a site goes down, and provides a Frontend Dashboard to visualize the uptime data via an API Gateway.

## Architecture
<img width="991" height="591" alt="Biểu đồ không có tiêu đề drawio" src="https://github.com/user-attachments/assets/51cc33f0-5215-4667-b173-beff8de76f3f" />

1. **Backend (Monitoring)**:
   - **AWS EventBridge**: Triggers the monitoring function every 5 minutes.
   - **AWS Lambda (Python)**: Pings a list of URLs and checks their HTTP status code.
   - **Amazon DynamoDB**: Stores timestamp, response time, and status of each check.
   - **Amazon SNS**: Sends email alerts if a website fails the health check.

2. **Frontend (Dashboard)**:
   - **AWS API Gateway**: Exposes a public REST API endpoint.
   - **AWS Lambda (API Fetcher)**: Reads data from DynamoDB and returns it as JSON for the API.
   - **Static Dashboard**: A simple HTML/JS page that queries the API Gateway and displays the status and response times of all monitored websites.

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/downloads) installed
- [AWS CLI](https://aws.amazon.com/cli/) configured with your AWS credentials
- Python 3.12 (if you wish to modify the Lambda functions locally)

## Setup & Deployment

1. **Configure your Variables**:
   Create a file named `terraform.tfvars` in the root directory and add your alert email:
   ```hcl
   alert_email = "your-email@example.com"
   ```

2. **Initialize Terraform**:
   ```bash
   terraform init
   ```

3. **Deploy the Infrastructure**:
   ```bash
   terraform apply
   ```
   *Type `yes` when prompted. After it finishes, Terraform will output an `api_url` in the terminal. Copy this URL!*

4. **Confirm SNS Subscription**:
   Check your email inbox (the one you provided in step 1). AWS SNS will send a confirmation link. You must click it to receive downtime alerts.

## Viewing the Dashboard

1. Go to the `frontend` folder and double-click `index.html` to open it in your web browser.
2. Paste the `api_url` you got from Step 3 into the input box and click **Load Data**.
3. You will now see the live status of all monitored websites!

## Customization

To monitor different URLs, update the `target_urls` list inside `main.tf`:
```hcl
variable "target_urls" {
  type = list(string)
  default = [
    "https://www.google.com",
    "https://httpstat.us/200", 
    "https://httpstat.us/503" # Used to demo a failing website
  ]
}
```
Run `terraform apply` again after changing the list.



## Cleanup

To destroy all resources and stop AWS billing:
```bash
terraform destroy
```
