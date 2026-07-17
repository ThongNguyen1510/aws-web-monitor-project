# AWS Website Monitor

A serverless website monitoring solution built on AWS and managed via Terraform. It checks the health of a specified website every 5 minutes and sends an email alert if the website goes down. It also logs every check to a DynamoDB table for historical analysis.

## Architecture
<img width="991" height="591" alt="Biểu đồ không có tiêu đề drawio" src="https://github.com/user-attachments/assets/51cc33f0-5215-4667-b173-beff8de76f3f" />

- **AWS EventBridge (CloudWatch Events):** Triggers the monitoring function on a 5-minute schedule.
- **AWS Lambda (Python 3.12):** Executes the health check against the target URL.
- **Amazon DynamoDB:** Stores the logs of each check, including timestamp, response time, and HTTP status code.
- **Amazon SNS:** Sends an email notification to the configured address if the website fails the health check.

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/downloads) installed
- [AWS CLI](https://aws.amazon.com/cli/) installed and configured with your AWS credentials
- Python 3.12 (for modifying Lambda if necessary)

## Setup & Deployment

1. **Clone the repository** (if you haven't already):
   ```bash
   git clone https://github.com/ThongNguyen1510/aws-web-monitor-project.git
   cd aws-web-monitor-project
   ```

2. **Configure your Variables**:
   Create a file named `terraform.tfvars` in the root directory and add your alert email:
   ```hcl
   alert_email = "your-email@example.com"
   ```
   *(Note: This file is ignored by git to keep your personal email private).*

3. **Initialize Terraform**:
   This command downloads the required AWS provider plugins.
   ```bash
   terraform init
   ```

4. **Review the Deployment Plan**:
   ```bash
   terraform plan
   ```

5. **Deploy the Infrastructure**:
   ```bash
   terraform apply
   ```
   *Type `yes` when prompted to create the resources.*

6. **Confirm SNS Subscription**:
   After deployment, AWS SNS will send an email to the address you provided in `terraform.tfvars`. **You must click the confirmation link in that email** to start receiving alerts.

## Customization

- To monitor a different URL, you can change the `target_url` variable in `main.tf` or override it in your `terraform.tfvars`:
  ```hcl
  target_url = "https://your-website.com"
  ```
- To change the frequency of checks, modify the `schedule_expression` in the EventBridge resource inside `main.tf`.



## Cleanup

To avoid ongoing AWS charges, you can destroy all deployed resources by running:
```bash
terraform destroy
```
