# Cloud Resume Challenge
I setup a serverless website for my resume that displays the number of site visits.  This project is hosted on AWS and managed through Terraform and GitHub Actions for CI/CD.

<br><br>

**DIAGRAM OF SETUP**
<br>
![Resume Cloud Challenge Diagram](https://github.com/techsoysauce/cloud-resume-challenge-final/blob/main/resume-cloud-diagram.png?raw=true)

<br><br>

## Architecture Overview:
(This repo offers a sanitized version of my code.)
### FRONT-END
* CloudFront with ACM
    * Loads private S3 html content to present an HTTPS resume website.
* S3 bucket for publishing front-end website code
    * Private bucket that is used by CloudFront that loads: HTML, CSS and JavaScript content.

### BACK-END
* API Gateway - HTTP v2
    * API Gateway allows Javascript code to perform RESTful API calls to get visitor count and increase count by 1.
* Python Lambda
    * API Gateway hooks into Lambda to process requests to DynamoDB table.
* DynamoDB Table
    * Table to record visit count.
* CloudWatch logs
    * Logs automatically provisioned to monitor API Gateway and Lambda calls.  Cloudwatch alarms configured to monitor for **4XX**, **5XX** and **latency** errors.

<br><br>

## Automation Technologies Used:
* Terraform
    * Created a terraform cloud workspace that builds out all back-end functionality (API Gateway, Lambda, DynamoDB table, IAM policies).
    * Used GitHub Actions to trigger **terraform apply** when changes are merged to *main* branch.  Automatically performs **terraform validate** and only merges changes when code passes tests.
* GitHub
    * Used for storage of front-end, back-end repos.
    * Changes are controlled via git vcs.
    * GitHub Actions workflow setup, that automatically updates S3 front-end contents when changes are merged with *main* branch.

<br><br>

## Additional Tools Used:
* Visual Studio Code for IDE
* Postman for verifying API functionality
* Sublime Text
* Google Chrome F12 (developer/lighthouse review of HTML code for performance/accesibility best practices)

