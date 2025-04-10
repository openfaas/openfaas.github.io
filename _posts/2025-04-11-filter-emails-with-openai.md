---
title: "Eradicate Cold Emails From Gmail for Good With OpenAI and OpenFaaS"
description: "Learn how to connect OpenAI's models to your Gmail to filter out unwanted messages with OpenFaaS, Python and Google Pub/Sub."
date: 2025-04-11
author_staff_member: han
categories:
- functions
- gmail
- ai
- google-cloud
- pubsub
dark_background: true
image: /images/2025-04-filter-emails-with-openai/background.png
hide_header_image: true
---

Learn how to connect OpenAI's models to your Gmail to filter out unwanted messages with OpenFaaS, Python and Google Pub/Sub.

Cold outreach emails, those unsolicited pitches that clog your inbox and waste your time can be a constant annoyance. Marketers are often using subject lines with clickbait or misleading subjects to try to get people to open their content. The worst part is that these types of messages often slip past traditional spam filters.

![Example of the type of cold outreach emails we regularly receive](/images/2025-04-filter-emails-with-openai/cold-outreach-example.png)
> Example of the type of cold outreach emails we regularly receive.

In this article we are going to build an OpenFaaS function to filter cold outreach messages from your Gmail inbox by leveraging the OpenAI API to analyze and classify emails. We will be using the new [Google Cloud Pub/Sub event connector](https://docs.openfaas.com/openfaas-pro/pubsub/) to receive Gmail inbox notifications and build an event driven email processing workflow. 

OpenFaaS supports event-driven architectures through the built-in asynchronous function concept, and through event connectors, to import events from external systems. The Google Cloud Pub/Sub is the latest addition to our [collection of official event triggers](https://docs.openfaas.com/reference/triggers/#triggers).

![Diagram showing the email filtering workflow](/images/2025-04-filter-emails-with-openai/spam-filter-workflow.png)

When a new message is received in Gmail the connector will invoke an OpenFaaS function. This function is going to fetch the content of any new emails in the inbox from the Gmail API and use the OpenAI API to analyze and classify each message. Based on the output of the LLM and its confidence an appropriate action, like labeling or deleting the message, can then be taken.

In the next sections we will run through the steps required to configure Google Cloud and set up Pub/Sub topics and permissions, deploy the gcp-pubsub-connector to the OpenFaaS cluster and create a function to process the Pub/Sub events. This example can serve as a starting point for more advanced email processing workflows or integrating other event-driven workflows with OpenFaaS using Google Cloud Pub/Sub.


## Prerequisites

- A Google Cloud Account
- An OpenAI Account.
- An OpenFaaS installation, k8s cluster with OpenFaaS Standard/Enterprise or OpenFaaS Edge


## Receive push notifications for mailboxes via Pub/Sub

The Gmail API provides push notifications that let you watch for changes to Gmail mailboxes. It publishes messages to Pub/Sub and applications can use the Pub/Sub API to subscribe and process those messages.

In order to complete the rest of this tutorial you will need to go to the [Google Cloud Console](https://console.cloud.google.com/) and select or create a new project. Make sure to enable the [Pub/Sub API](https://console.cloud.google.com/apis/enableflow?apiid=pubsub.googleapis.com) and [Gmail API](https://console.cloud.google.com/apis/enableflow?apiid=gmail.googleapis.com) for your project.

### Create a topic for Gmail notifications

Create a topic that the Gmail API should send notifications to. The topic name can be any name you choose under your project, i.e. `projects/<project_id>/topics/<name>`. We will create a topic named `gmail-notifications`.

Cloud Pub/Sub requires that you grant Gmail privileges to publish notifications to your topic. To do this, you need to grant publish privileges to `gmail-api-push@system.gserviceaccount.com`. You can do this using the [Cloud Pub/Sub Developer Console permissions interface](https://console.cloud.google.com/project/_/cloudpubsub/topicList) or run this command with the [gcloud CLI](https://cloud.google.com/sdk/gcloud):

```sh
export PROJECT_ID=""

gcloud pubsub topics add-iam-policy-binding projects/$PROJECT_ID/topics/gmail-notifications \
  --member="serviceAccount:gmail-api-push@system.gserviceaccount.com" \
  --role="roles/pubsub.publisher"
```

### Authenticate with the Gmail API

Obtaining an access token for authenticating to the Gmail API requires a user interaction to approve the application in a consent screen. The spam filtering function that we are going to create is intended to run as a headless function so it won't be possible to redirect for consent. In order to keep things as simple as possible for this tutorial we will use a small python script that can be run separately to obtain an access token and save it to a file. The token file can be passed to our headless function as an [OpenFaaS secret](https://docs.openfaas.com/reference/secrets/) and used to authenticate with the Gmail API.

Save the following script in a file called `auth.py`:

```python
from google.oauth2.credentials import Credentials
from google_auth_oauthlib.flow import InstalledAppFlow
from google.auth.transport.requests import Request
import os

SCOPES = ['https://www.googleapis.com/auth/gmail.modify']

def authenticate_gmail():
    creds = None
    # Ensure .secrets directory exists
    os.makedirs('.secrets', exist_ok=True)
    
    if os.path.exists('.secrets/gmail-token'):
        creds = Credentials.from_authorized_user_file('.secrets/gmail-token', SCOPES)
    if not creds or not creds.valid:
        if creds and creds.expired and creds.refresh_token:
            creds.refresh(Request())
        else:
            flow = InstalledAppFlow.from_client_secrets_file('.secrets/credentials.json', SCOPES)
            creds = flow.run_local_server(port=0)
        with open('.secrets/gmail-token', 'w') as token:
            token.write(creds.to_json())
    return creds

def main():
    try:
        creds = authenticate_gmail()
        if creds:
            print("Successfully authenticated with Gmail!")
            print(f"Token saved to ./secrets/gmail-token")
        else:
            print("Failed to authenticate with Gmail")
    except Exception as e:
        print(f"Error during authentication: {str(e)}")

if __name__ == "__main__":
    main()
```

Make sure you install the required libraries to run the script:

```bash
pip install --upgrade google-api-python-client google-auth-httplib2 google-auth-oauthlib
```

The script is also available [on GitHub](https://github.com/welteki/gmail-spam-detection/blob/main/auth.py)

1. Configure the OAuth consent screen

    If this has not been done already, [configure an OAuth consent screen](https://developers.google.com/workspace/gmail/api/quickstart/python#configure_the_oauth_consent_screen) for your Google Cloud Project.

2. Get client credentials

    The script needs a client Id and credentials to run the OAuth consent flow and obtain an access token. [Create a new desktop app client](https://developers.google.com/workspace/gmail/api/quickstart/python#authorize_credentials_for_a_desktop_application) in your Google Cloud project. Download the JSON file with the credentials and save it as `.secrets/credentials.json`.

3. Run the authentication script

    ```bash
    python auth.py
    ```

    This will open a browser window and ask you to login with a Google account. Login with the account you want to receive Gmail inbox notifications for and approve the app. After completing the OAuth flow you should see the access token file got created at `.secrets/gmail-token`.

### Configure Gmail to send notifications

To configure Gmail accounts to send notifications to Pub/Sub the `watch` endpoint for a mailbox has to be called. When calling watch we need to provide the Pub/Sub topic on which we want to receive notifications and a list of labels to filter on. We will be filtering on the `INBOX` label. This allows us to receive notifications only for changes to the inbox e.g. when a new message is received.

Example request:

```
POST "https://www.googleapis.com/gmail/v1/users/me/watch"
Content-type: application/json

{
  topicName: "projects/<project-id>/topics/gmail-notifications",
  labelIds: ["INBOX"],
  labelFilterBehavior: "INCLUDE",
}
```

We will start by creating a new function to call the `watch` endpoint. Scaffold a new Python function using the faas-cli.

```bash
# Pull the python3-http template from the store
faas-cli template store pull python3-http

# Scaffold the function.
faas-cli new gmail-spam-detection --lang python3-http

```

We are using the `python3-http` template to scaffold the function. This template creates a minimal function image based on alpine linux. If your function depends on modules or packages that require a native build toolchain such as Pandas, Kafka, SQL etc. we recommend using the `python3-http-debian` template instead.

Update `handler.py` of the new function.

```python
import os.path
import logging
from google.oauth2.credentials import Credentials
from googleapiclient.discovery import build
from google.auth.transport.requests import Request

project_id = os.getenv('project_id')
# Pub/Sub topic to send inbox notifications to.
notification_topic = os.getenv('notification_topic')


def handle(event, context):
    try:
        gmail_client = get_gmail_client()
        request = {
            'labelIds': ['INBOX'],
            'topicName': f'projects/{project_id}/topics/{notification_topic}',
            'labelFilterBehavior': 'INCLUDE'
        }
        
        gmail_client.users().watch(userId='me', body=request).execute()
        logger.info("Successfully set up Gmail watch on INBOX with topic: %s", request['topicName'])
    except Exception as e:
        logger.error("Failed to set up Gmail watch: %s", str(e))
        return { "statusCode": 500, "body": "Failed to watch Gmail inbox" }

    return {
        "statusCode": 202,
    }
```

The function handler folder also includes a `requirements.txt` file. All Python packages the function code depends on need to be added here.

```
google-api-python-client
google-auth-httplib2
google-auth-oauthlib
```

When invoked the handler initializes a new Gmail API client by calling the `get_gmail_client` function. It uses this client to call the `watch` endpoint and configures Gmail to send notifications for all changes to the inbox.

Let's take a look at the `get_gmail_client` function.

```python
def get_gmail_client():
    # Scopes to use for authenticating with Gmail.
    scopes = ['https://www.googleapis.com/auth/gmail.modify']

    creds = None
    if os.path.exists('/var/openfaas/secrets/gmail-token'):
        creds = Credentials.from_authorized_user_file('/var/openfaas/secrets/gmail-token', scopes)
    if not creds:
        raise Exception("Failed to load credentials")
    if creds.expired and creds.refresh_token:
        creds.refresh(Request())
    
    return build('gmail', 'v1', credentials=creds)
```

The function tries to initialize the Gmail API client with the credentials file mounted at `/var/openfaas/secrets/gmail-token`. It reads the access token credentials and checks if they are expired. If this is the case the refresh token is used to obtain new credentials before returning the Gmail API client.

Note that the `gmail-token` file is mounted in the `/var/openfaas/secrets` directory. This is the default location used by OpenFaaS to mount secrets. 

> Confidential configuration like API tokens, connection strings and passwords should never be made available in the function through environment variables. Use [OpenFaaS secrets](https://docs.openfaas.com/reference/secrets/) instead.

The function configuration in the `stack.yaml` file needs to be updated to add the environment variables for the Google Cloud project id and name of the Pub/Sub topic to use for notifications.To tell OpenFaaS which secrets to mount for a function add the secret names to the `secrets` section.

```diff
functions:
  gmail-spam-detection:
    lang: python3-http
    handler: ./gmail-spam-detection
    image: ${SERVER:-ttl.sh}/${OWNER:-openfaas-demo}/gmail-spam-detection:0.0.1
+    environment:
+      project_id: "your-project-id"
+      notification_topic: "gmail-notifications"
+    secrets:
+      - gmail-token
```

Make sure the secrets are added to OpenFaaS before deploying the function.

```bash
# Gmail access token
faas-cli secret create \                                  
    gmail-token \
    --from-file .secrets/gmail-token
```

Deploy and invoke the function to configure notifications for Gmail.

```bash
faas-cli up
echo | faas-cli invoke gmail-spam-detection
```

**Renew the watch**

The mailbox watch expires after 7 days and the `watch` endpoint has to be re-called to keep receiving updates. The docs for the Gmail API recommend calling the `watch` once per day. The [OpenFaaS cron-connector](https://docs.openfaas.com/reference/cron/#cron-connector) makes it very convenient to trigger functions on a timed-basis by simply adding annotations to a function.

Follow the instructions in the docs to deploy the cron-connector in your cluster.

Update the `stack.yaml` file to add a `topic` and `schedule` annotation for the cron-connector and redeploy the function.

```diff
functions:
  gmail-spam-detection:
    lang: python3-http
    handler: ./gmail-spam-detection
    image: ${SERVER:-ttl.sh}/${OWNER:-openfaas-demo}/gmail-spam-detection:0.0.1
    environment:
      project_id: "your-project-id"
      notification_topic: "gmail-notifications"
    secrets:
      - gmail-token
+    annotations:
+        topic: cron-function
+        schedule: "0 2 * * *"
```

With this configuration the cron-connector will invoke the function at 2:00 AM every day to renew the watch.

![Diagram showing how the watch for Gmail notifications is renewed on a schedule using the cron-connector](/images/2025-04-filter-emails-with-openai/gmail-watch.png)
> Renew the watch for Gmail notifications on a schedule using the cron-connector.

## Deploy the Google Cloud Pub/Sub connector

In the previous sections we created a Pub/Sub topic for Gmail notifications and configured the Gmail API to publish messages to this topic. We now need to subscribe to these notifications and trigger our function whenever there is a new message.

Follow the installation instructions in [the docs](https://docs.openfaas.com/openfaas-pro/pubsub-events/#installation) to deploy the Pub/Sub connector. Use the following `values.yaml` file to configure the connector to use the `gmail-notifications-sub` subscription. Make sure to replace the `projectID` parameter with your own project ID.

```yaml
projectID: "your-project-id"
subscriptions:
  - gmail-notifications-sub
```

To verify notifications are being sent you can deploy the printer function. This function prints out the request body and headers and can be used to test connectors and inspect the message contents.

```bash
faas-cli store deploy printer --annotation topic=gmail-notifications-sub
faas-cli logs printer
```
To test the connector you can manually send a message to the `gmail-notifications` topic from the Google Cloud console. Or send a test email to your Gmail inbox to see an actual notification message.

The body of the Gmail notification messages is a JSON string containing the email address and the new mailbox history ID for the user:

```json
{"emailAddress": "user@example.com", "historyId": "9876543210"}
```

## Handle Pub/Sub messages and filter spam emails

In this section we are going to extend the `gmail-spam-detection` function to handle the Pub/Sub messages for mailbox updates. Whenever a mailbox update occurs that matches the `watch` we configured, a message is published to the `gmail-notifications` Pub/Sub topic describing the change. The OpenFaaS Pub/Sub connector receives the message and in turn invokes any function that has registered interest through the topic annotation.

Next our function needs to:

- Parse the notifications message and get the current historyId
- Get the IDs for all new messages added to the inbox since the last known historyId.
- Fetch the content of the email message using the message ID
- Invoke the OpenAI API with the content of each message and ask it to analyze and classify the message.
- Take some action based on the classification response. In this case we are just going to add a label when a message is classified as spam.

![Sequence diagram - Updating watch and processing events](/images/2025-04-filter-emails-with-openai/sequence-diagram.png)

The Gmail API does not send a list of changed messages in the notification. Instead we receive a historyId. The `history.list` endpoint can be used to get the change details for the user since their last known historyId.

To get an initial historyId the `watch` endpoint can be called. Each time a new notification is received we call the `history.list` endpoint to get changes that occurred between the last historyId and the receipt of the notification message. We can then filter out the ids of messages that were added to the inbox from the list of events returned. After we have processed the message the last historyId gets replaced with the historyId from the current notification.

```python
def get_changed_messages(gmail_client, user_id='me', start_history_id=None):
    response = gmail_client.users().history().list(
        userId=user_id,
        startHistoryId=start_history_id,
        labelId='INBOX', # Only return messages in the INBOX
        historyTypes=['messageAdded']
    ).execute()

    message_ids = []
    if 'history' in response:
        for history in response['history']:
            if 'messages' in history:
                for msg in history['messagesAdded']:
                    message = msg['message']
                    message_ids.append(message['id'])
                    
    return message_ids
```

Lets start by refactoring `handler.py`. We will move the code to renew the `watch` to a separate function, `handle_watch` and create a new function `handle_notification`. The `handle_watch` function gets called if the request is coming from the cron connector to renew the watch or when the `/watch` path gets invoked explicitly. All other invocations get handled by `handle_notifications`.

Before our function starts we call the `watch` endpoint of the Gmail API to get the initial historyId. We are also reading secrets, environment variables and initializing the OpenAI client.

Let's start by updating `handler.py`:

```python
import os.path
import json
import base64
import logging
from openai import OpenAI
from google.oauth2.credentials import Credentials
from googleapiclient.discovery import build
from google.auth.transport.requests import Request

def watch(gmail_client, project_id, topic):
    request = {
        'labelIds': ['INBOX'],
        'topicName': f'projects/{project_id}/topics/{topic}',
        'labelFilterBehavior': 'INCLUDE'
    }
    
    response = gmail_client.users().watch(userId='me', body=request).execute()
    return response.get('historyId')

# Configuration
project_id = os.getenv('project_id')
# Pub/Sub topic to send inbox notifications to.
notification_topic = os.getenv('notification_topic')

# Prompt to use for classifying emails.
classify_prompt = read_prompt()
# Label to add to cold outreach emails.
cold_outreach_label = os.getenv('cold_outreach_label')

# OpenAI API key.
openai_api_key = read_secret("openai-api-key")
openAIClient = OpenAI(api_key=openai_api_key)

# State
lastHistoryId = watch(get_gmail_client(), project_id, notification_topic)

def handle(event, context):
    if event.path == '/watch' or event.headers.get('X-Connector') == 'cron-connector':
        # Handle watch requests from the cron-connector.
        return handle_watch(event, context)
    else:
        # Handle notification requests from the pubsub-connector.
        return handle_notification(event, context)
```

The `handle_notification` function executes the steps we described at the beginning of the section when a Pub/Sub messages is received.

```python
def handle_notification(event, context):
    global lastHistoryId

    try:
        eventData = parse_pubsub_event(event)

        email = eventData["emailAddress"]
        historyId = eventData["historyId"]
        logger.info(f"Received notification: email: {email}, historyId: {historyId}")
    except Exception as e:
        return { "statusCode": 404, "body": "Invalid pubsub event" }

    try:
        gmail_client = get_gmail_client()
        # Ensure the label for tagging messages exits.
        label_id = get_or_create_label(gmail_client, cold_outreach_label)
        # Get all messages that have been added to the INBOX since the last notification.
        msg_ids = get_changed_messages(gmail_client, start_history_id=lastHistoryId)
    except Exception as e:
        logger.error(f"Failed to handle notification: {e}")
        return { "statusCode": 500, "body": "Failed to handle notification" }

    for msg_id in msg_ids:
        try:
            # Get the content of the email using the Gmail API.
            msg_content = get_email_content(gmail_client, msg_id)
            # Call the OpenAI API to classify the email.
            classification = classify_email_content(classify_prompt, msg_content)
            logger.info(f"Classification response for message {msg_id}: {classification}")

            # If the email is classified as cold outreach, add a label to the message.
            if classification['is_cold_outreach']:
                add_label(gmail_client, label_id, msg_id)
        except Exception as e:
            logger.warning(f"Failed to process message {msg_id}: {e}")
            continue
    
    # Update the history ID to indicate we have processed messages up to this point.
    lastHistoryId = historyId

    return { "statusCode": 202 }
```

The full `handler.py` implementation [can be found on GitHub](https://github.com/welteki/gmail-spam-detection/blob/main/gmail-spam-detection/handler.py).

### Classifying Emails using the OpenAI API

To determine whether an email is a cold outreach message, we send a structured prompt to the OpenAI API that includes key metadata from the email: sender, address, subject and content.

The prompt asks the model to return a classification in a specific JSON format. This ensures consistent, machine-readable output that can be easily parsed and used downstream in the function logic. We ask the language model to include a `confidence` and `reasoning` field to help with classification and debugging. The reasoning can be logged in the function and is useful for debugging and during development to improve the prompt and understand why an email was classified as spam. 

```
Analyze the following email and determine if it is a cold outreach email.

Consider the following indicators:
- Keywords like "proposal," "partnership," "demo," "schedule," "solution," or "reach out."
- Generic greetings (e.g., "Dear [Name]," "Hi there") with no personal context.
- Mentions of companies, tools, or services being offered.
- Links to scheduling tools (e.g., Calendly) or company websites.
- Formal or overly enthusiastic tone typical of sales pitches.

Return your answer in the following JSON format:
{
  "is_cold_outreach": [true | false],
  "confidence": [float between 0 and 1],
  "reasoning": "Short explanation",
  "from": "Sender address of the email",
  "subject": "The email subject"
}

If the email is incomplete or ambiguous, base your judgment on available content and note any limitations in the reasoning.

Email:
```

The classification function shown below constructs the full prompt dynamically based on the email content and sends it to the OpenAI Chat API using the `gpt-3.5-turbo` model:

```python
def classify_email_content(prompt, content):
    full_prompt = f"{prompt}\n\nFrom: {content['from']}\nSubject: {content['subject']}\nBody:\n{content['body']}"
    response = openAIClient.chat.completions.create(
        model="gpt-3.5-turbo",
        messages=[
            {"role": "system", "content": "You are an assistant that classifies emails. Always respond with JSON."},
            {"role": "user", "content": full_prompt}
        ],
        temperature=0.2,  # Low randomness for consistent output
        max_tokens=300
    )
    return response.choices[0].message.content
```

When implementing your own version of the function feel free to experiment with different available models. The prompt we use in this example is very minimal and you might want to give it more context and examples for a more reliable and consistent output. OpenAI also has a great article on [how to optimize the correctness and accuracy of an LLM for specific tasks](https://platform.openai.com/docs/guides/optimizing-llm-accuracy).


### Deploy the function

Before deploying the function we have to update the `stack.yaml` configuration to make sure it gets triggered by the Pub/Sub connector. We need to add the name of the Pub/Sub subscription we want to receive messages for to the topic annotation. Also add the OpenAI API key to the list of secrets.

```diff
functions:
  gmail-spam-detection:
    lang: python3-http
    handler: ./gmail-spam-detection
    image: ${SERVER:-ttl.sh}/${OWNER:-openfaas-demo}/gmail-spam-detection:0.0.1
    environment:
      project_id: "your-project-id"
      notification_topic: "gmail-notifications"
    secrets:
      - gmail-token
+     - openai-api-key
    annotations:
-        topic: cron-function
+        topic: cron-function,gmail-notifications
        schedule: "0 2 * * *"
```

Generate a new API key from your OpenAI dashboard and save it at `.secrets/openai-api-key`.

Make sure the secret for the OpenAI API key is added added to OpenFaaS:

```bash
faas-cli secret create \
  openai-api-key \
  --from-file .secrets/openai-api-key
```

Deploy the function:

```bash
faas-cli up
```

You should see the function gets triggered whenever there is a new email in your inbox. Use the faas-cli to check the logs of the function and see the reasoning behind decisions.

```bash
faas-cli logs gmail-spam-detection
```

## Taking it further

**Add senders to a blacklist**

When an email is flagged as spam, the sender's address can be added to a blacklist stored in persistent storage. This ensures that any future emails from the same sender are immediately flagged as spam, reducing the number of requests made to the OpenAI API and saving costs, especially in high-traffic scenarios.

**Support multiple inboxes**

For simplicity, the function in this tutorial handles a single user and Gmail inbox. To support multiple users, you can deploy multiple instances of the spam filtering function, each configured for a different user. Alternatively, you could modify the code to handle multiple users from a single function by implementing a system to store and retrieve access tokens for different users.

**Use a different LLM**

While this tutorial uses the OpenAI API, there are numerous other language models available that can be integrated into this workflow. For instance, [Google's Gemini](https://ai.google.dev/) or [Meta's Llama](https://www.llama.com/) models offer robust natural language processing capabilities. Self-hosted open-source models like DeepSeek can be used for those who prefer to maintain control over their data and infrastructure. These models can be fine-tuned to better suit specific needs, providing flexibility and potentially reducing costs associated with API usage.

## Conclusion

In this tutorial, we've explored how to enhance email filtering by creating a custom OpenFaaS workflow with Google Cloud Pub/Sub for receiving Gmail inbox notifications and OpenAI for analyzing emails. This approach allows for more sophisticated detection of cold outreach emails, which are often missed by traditional spam filters. We encourage you're to experiment with different language models, or implement built similar AI driven data processing pipelines, the possibilities for customization and improvement are vast. This tutorial is intended to serve as a foundation for building more advanced and tailored AI data processing workflows, demonstrating the capabilities and flexibility of OpenFaaS.

We showed you how to deploy and use the [OpenFaaS GCP Pub/Sub connector](https://docs.openfaas.com/openfaas-pro/pubsub-events) to receive Gmail notification. The Pub/Sub connector allows teams and companies who are already using Google Cloud Pub/Sub or integrating with the Google Cloud platform to easily trigger their OpenFaaS functions.

If you’re approaching OpenFaaS and have no existing message broker in use such as AWS SQS, Apache Kafka, then we strongly recommend using the built-in [NATS JetStream support for asynchronous processing](https://docs.openfaas.com/openfaas-pro/jetstream/), it provides a convenient HTTP API, and is built into every OpenFaaS installation.

[Reach out to us](https://openfaas.com/pricing) if you’d like a demo, or if you have any questions about the GCP Pub/Sub connector, or OpenFaaS in general.

See also:

- [Stream OpenAI responses from functions using Server Sent Events ](https://www.openfaas.com/blog/openai-streaming-responses/)
- [Scale to zero GPUs with OpenFaaS, Karpenter and AWS EKS](https://www.openfaas.com/blog/scale-to-zero-gpus/)
- [How to transcribe audio with OpenAI Whisper and OpenFaaS ](https://www.openfaas.com/blog/transcribe-audio-with-openai-whisper/)