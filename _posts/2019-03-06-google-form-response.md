---
title: "Process Google Forms Responses with OpenFaaS"
description: Burton outlines how you can use an OpenFaaS function to send Google Forms responses into a Slack channel using .NET and Serverless Functions.
date: 2019-03-06
image: /images/google-form-response/dots.jpg
categories:
  - productivity
  - C#
  - dotnet
  - tutorial
  - examples
author_staff_member: burton
dark_background: true
---

In this post, I'll walk you through to use OpenFaaS and dotnet / C# to get notified on Slack every time that someone fills out your Google Form.

Google Forms are really convenient ways to collect user feedback, organise an event or for a Slack sign-up flow. We'll be building a workflow with Google Forms, OpenFaaS and Functions written in C#. When we're finished - every time someone fills out our Form, we'll send a message to a Slack channel with the responses from the form. This means you and your team can give them a warm welcome into the community.

## Pre-requisites

You will need OpenFaaS running locally along with the `faas-cli` installed. Head over to the deployment guide in the [docs](https://docs.openfaas.com) if you don't have this set up already.

All of the code is available in a [GitHub Repo](https://github.com/burtonr/openfaas-google-form-handler)

You can optionally install [.NET Core](https://dotnet.microsoft.com/download) locally

I recommend [VSCode](https://code.visualstudio.com/) as an editor for Linux, Mac, and Windows

## Create the Signup Form

Our first task is to create a Google Form that people can fill out to request access to Slack. We'll need some background information and the reason for wanting to join the workspace.

For this step you will need a Google account. The link may ask you to sign in, or create an account if you're not already signed in.

* Head over to [Google Forms](https://docs.google.com/forms/u/0/) site to start the process
* Click the "Template Gallery" link in the upper right side of the page and select the one labeled "RSVP"
    * There are several templates available to jump-start the process. You could also start with a "Blank" form

![New Form Template](/images/google-form-response/new-rsvp-template.png)

* So we don't forget, first update the settings so that anyone can sign up.
* Click the cog (or gear) icon in the top right menu bar to open the form settings menu

![Options Menu Bar](/images/google-form-response/form-options-menu.png)

* Tick the box for "Collect email addresses" so that their email is automatically sent with the form

![Form Options](/images/google-form-response/form-settings-menu.png)

> Note: Be sure to un-tick the option "Limit to 1 response". Don't want to limit your users. "Respondents will be required to sign in to Google."

* Now, edit the form questions and answer types to meet your needs.
    * Since we ticked the "Collect email addresses" box, "Email" will be the first question, and required.
    * I won't go into detail of how to create a Google Form here, so feel free to experiment!

* Here's the completed form that we'll be sharing
![Complete Form](/images/google-form-response/example-form.png)

* Next, click the vertical ellipsis extended menu, and select "< > Script editor"
![Extended Form Menu](/images/google-form-response/extended-options-menu.png)
* Replace what's there with the below snippet:
  * You'll need to replace the value of `baseURL` with your OpenFaaS gateway URL
  * Here, I'm using [ngrok](https://ngrok.com/) to proxy to my local gateway at `127.0.0.1:8080`
  * The function that we will be creating next will be called "signup-form" 

```js
// Put your OpenFaaS gateway public URL here
var baseURL = "http://02626413.ngrok.io";
var functionURL = "/function/signup-form";

function onSubmit(entry) {
  var response = entry.response.getItemResponses();
  
  var answers = {};

    for (var j = 0; j < response.length; j++) {
        var itemResponse = response[j];
        // { question: response }
        answers[itemResponse.getItem().getTitle()] = itemResponse.getResponse();
    }
  
    var options = {
        method: "post",
        payload: JSON.stringify(answers)
    };
  // Send to OpenFaaS
  UrlFetchApp.fetch(baseURL + functionURL, options);
};

```

> Also available on [GitHub Gist](https://gist.github.com/burtonr/ba12d9c1e0905b77344b41acbe147eb3)

* Now, set up your script trigger so that this script will get run when a user clicks "Submit"
* Go to the "Edit" menu, and select "Current project's triggers"
  * At this point, if you haven't already, it may pop-up asking you to name your project. This is so you can reference it later from your Google Developer Hub

![Script Edit Menu](/images/google-form-response/script-edit-menu.png)

* Create a new trigger
  * Set "Select event source" to "From Form"
  * Set "Select event type" to "On form submit"

![New Trigger Menu](/images/google-form-response/new-form-trigger.png)

You'll need to grant this new project and triggers access to your Google account so that it can read the responses and execute your script

Great! Now your form is all set up and ready to go! You can always go back and edit anything later as you test it with your function

Now, let's build a function to handle the responses!

## Create the Form Handler Function
I will be using C# as the language to write the handler function in. The code is not overly complex, so it should be easy to port it over to your language of choice.

> If you don't already have `faas-cli` installed, do that now. [Install OpenFaaS CLI](https://docs.openfaas.com/cli/install/)

In your terminal of choice, create the new function from the `csharp` template:

```sh
$ faas-cli new signup-form --lang csharp
```

We're going to need to add a dependency to `Newtonsoft.Json` to parse the JSON request from the form. We'll also add the C# Slack SDK to make it easy to post a message to the appropriate channel. The dependencies will be added from Nuget via `dotnet add`:

```sh
$ cd signup-form
$ dotnet add package Newtonsoft.Json
$ dotnet add package SlackAPI
```

In your favorite IDE or text editor, open the directory which contains your function

Open the `FunctionHandler.cs` file in the `signup-form` directory. What you'll see is the basic "Hello World" sample code that's included with the template. We're going to replace the contents of the `FunctionHandler` class with the code sample below.

This takes the input, parses it as a JSON string into an object (we'll define a little later), turns the responses into an easy to read message, and posts that message to a designated Slack channel for all of the signup requests.

```csharp
public class FunctionHandler
{
  public string Handle(string input) {
    FormResponse formResponse = JsonConvert.DeserializeObject<FormResponse>(input);

    var message = FormatMessage(formResponse);
    var slackSent = SendToSlack(message);

    Console.WriteLine($"Response recorded from {formResponse.Email}. Slack posted? {slackSent}");

    return slackSent;
  }

  private string FormatMessage(FormResponse response)
  {
    // Convert the responses into an easy to read message
    ...
  }

  private bool SendToSlack(string message)
  {
    // Send the message to a Slack channel
    ...
  }

  private string GetSecret(string name)
  {
    // Get the Slack API token stored as a secret
    ...
  }
}
```

Here is the class definition for the form response. Again, using the Newtonsoft.Json NuGet package to define which JSON fields are parsed into which object property

```csharp
public class FormResponse
{
  [JsonProperty("Email")]
  public string Email { get; set; }

  [JsonProperty("First Name")]
  public string FirstName { get; set; }

  [JsonProperty("Last Name")]
  public string LastName { get; set; }

  [JsonProperty("Company")]
  public string Company { get; set; }

  [JsonProperty("Location")]
  public string Location { get; set; }

  [JsonProperty("I'm joining to")]
  public string JoinReason { get; set; }
}
```

As you can see, the questions are the properties of the JSON string that is passed into the function, so we need to explicitly define the mapping between the JSON property and the class property since there are spaces and invalid characters.

The `FormatMessage` method is just taking each of the properties and putting the values into a sentence, so I won't go into explaining that.

The `SendToSlack` method is shown below. It is calling the `GetSecret` method in order to get the Slack token that will be stored as a secret in the cluster. Then, building the request and posting to Slack using the `SlackAPI` NuGet package we added earlier.

```csharp
private bool SendToSlack(string message)
{
  var token = GetSecret("slack-token");
  var client = new SlackTaskClient(token);

  var channel = "signup";
  // Not using the async operator for simplicity in this example only
  var response = client.PostMessageAsync(channel, message);

  return response.Result.ok;
}
```

The `GetSecret` method reads the secret from the file system. OpenFaaS stores the secrets in the `/var/openfaas/secrets` directory as the standard

```csharp
private string GetSecret(string name)
{
  try
  {
    using (StreamReader sr = new StreamReader("/var/openfaas/secrets/slack-token"))
    {
      String line = sr.ReadToEnd();
      return line;
    }
  }
  catch (IOException e)
  {
    Console.WriteLine("The file could not be read:");
    Console.WriteLine(e.Message);
    return string.Empty;
  }
}
```

## Setup the Slack App

Here, we'll create a simple Slack App that will allow posting messages to a specific channel in your Slack workspace. You will need access to:

* Create a new Slack App on the [Slack API site](https://api.slack.com/apps?new_app=1)
  * You'll need to sign in to your workspace in the browser

![Create Slack App](/images/google-form-response/create-slack-app.png)

* We need to give the app permissions to post messages
* Click on the "Permissions" button in the "Add features and functionality" section
* Then, scroll down to the "Scopes" section

![Slack Permissions Scopes](/images/google-form-response/slack-app-scope.png)

* Select the "Post to specific channels in Slack" option
* Now, the "Install App to Workspace" button is enabled in the first section labeled "OAuth Tokens & Redirect URLs"

![Install Slack App](/images/google-form-response/slack-install-app.png)

* Select the channel you want to post messages to
> If the channel doesn't yet exist, you'll need to create it and refresh the page
* Now, the API token will be presented to you

![Slack API Token](/images/google-form-response/slack-app-token.png)

That's it for the Slack App. There are more options available on the App Settings page. You can change the icon, color, name, etc. Have some fun with it!

Now, back to the function...

## Deploy the Function

The final step, deploying your function! 

As mentioned earlier, this assumes that you already have an OpenFaaS cluster running and available to deploy to.

You don't want to commit your Slack API token with the function, or have it as an easily accessible environment variable, we'll add it as a secret on the cluster. With OpenFaaS, we don't need to worry about which orchestration the function is running on. We will create the secret using the OpenFaaS CLI.

Read more about [Unifying Secrets with OpenFaaS](/blog/unified-secrets) 

* Copy your Slack API token into a new file `slack-token`
  * This is so the token is not in the terminal history
* Create the secret with OpenFaaS CLI
  * `faas-cli secret create slack-token --from-file ./slack-token --gateway https://<your OpenFaaS gateway URL and port>`
* Update the `signup-form` function's yaml file so it will have access to the secret
  * Be sure to update the `image` field as well so you will be able to push the image to Docker Hub (or your private repository)

```yaml
provider:
  name: faas
  gateway: http://127.0.0.1:8080
functions:
  signup-form:
    lang: csharp
    handler: ./signup-form
    image: burtonr/signup-form:latest
    secrets:
      - slack-token
```

* Now, with a single command, we can build the image, push the image to a repository, and deploy the function

```sh
$ faas-cli up
```

* When that's complete, you should see a successful deployment message like this:

```sh
Deploying: signup-form.

Deployed. 202 Accepted.
URL: http://<openfaas gateway>/function/signup-form
```

* Now you can send out links to your Google Form and see the messages pouring in to your Slack workspace.

## Summary

We've successfully created a custom Google Form, added a script that will pass the questions and answers to an OpenFaaS function. That function then parses the responses, and creates a nice message which is posted to Slack introducing the new member to the team. 

You should see something like this in your Slack channel:

![Request Slack Message](/images/google-form-response/slack-message.png)

In the image we're posting a message so that the team is aware of the request to join with some information to help give a warm welcome. You could easily modify the function to send the invite link directly.

Now that you've seen my example, what would you create? You could create a form to request access to an internal IT system, organize a team-lunch or any other kind of questionnaire.

For questions, comments and suggestions follow us on [Twitter @openfaas](https://twitter.com/openfaas) and join the [Slack community](https://docs.openfaas.com/community).

## See Also

[How to build a Kubernetes Cluster with ARM Raspberry Pi then run .NET Core on OpenFaaS](https://www.hanselman.com/blog/HowToBuildAKubernetesClusterWithARMRaspberryPiThenRunNETCoreOnOpenFaas.aspx) by Scott Hanselman

[Building a Raspberry Pi Kubernetes Cluster and running .NET Core - Alex Ellis & Scott Hanselman (video)](https://www.youtube.com/watch?v=ZyTLMnzehyU)
