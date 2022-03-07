# Cloud Resume Challenge
I setup a serverless website for my resume that displays the number of site visits.  This project is hosted on AWS and managed through Terraform and GitHub Actions for CI/CD.

## Architecture Overview:
* CloudFront with ACM
    * Loads private S3 html content to load an HTTPS resume website
* S3 bucket for publishing front-end website code
    * Private bucket that is used by CloudFront that loads: html, css and javascript content
* API Gateway - HTTP v2
    * API Gateway allows Javascript code to perform RESTful API calls to get visitor count and increase count by 1.
* Python Lambda
    * API Gateway hooks into Lambda to process requests to DynamoDB table.
* DynamoDB Table
    * Table to record visit count.

## Automation technologies used:
* Terraform
    * Created a terraform cloud workspace that builds out all back-end functionality (API Gateway, Lambda, DynamoDB table, IAM policies).
    * Used GitHub Actions to trigger **terraform apply** when changes are merged to *main* branch.  Automatically performs **terraform validate** and only merges changes when code passes tests.
* GitHub
    * Used for storage of front-end, back-end repos.
    * Changes are controlled via git vcs
    * GitHub Actions workflow setup that automatically updates S3 front-end contents when changes are merged with *main* branch.

