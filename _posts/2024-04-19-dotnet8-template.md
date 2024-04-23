---
title: Introducing a new OpenFaaS template for C# and .NET 8
description: 
date: 2024-04-19
categories:
- dotnet
- functions
- templates
- postgres
dark_background: true
image: "/images/2024-04-dotnet8-csharp/background.png"
author_staff_member: han
hide_header_image: true
---

We have created a new OpenFaaS template for C# and .NET 8.0 and it's based on the [Minimal API](https://learn.microsoft.com/en-us/aspnet/core/fundamentals/minimal-apis?view=aspnetcore-8.0) of ASP.NET Core.

In the past we provided a basic `csharp` template that used the original forking mode of the OpenFaaS watchdog, which created one process per request, and was less efficient than newer templates where one process would handle many requests concurrently.

There were also a number of unofficial templates adopted by the community, which were not necessarily kept up to date, or something that we could support directly.

The new template is called: `dotnet8-csharp` and has the following benefits:

- Adding NuGet packages to a function for additional dependencies.
- Register services for dependency injection
- Uses the latest ASP.NET Core middleware
- Based upon the highly-performant Kestrel HTTP server

In the next section we will walk through an example that show you how to develop and deploy an OpenFaaS function with C# and the new template.

The function will read rows from a database table, and return them as JSON.

We'll then briefly discuss a few other features like dependency injection and how to use ASP.NET middlewares such as the static fileserver.

OpenFaaS templates provide a handler, some way to add dependencies, and a build system to create an OCI compatible image. But if you're already building your own images, you can deploy them to OpenFaaS if they provide a HTTP server. See also: [Build ASP.NET Core APIs with Kubernetes and OpenFaaS](https://www.openfaas.com/blog/asp-net-core/)

## Prerequisites

We won't go into detail on how to deploy OpenFaaS and assume you are already running OpenFaaS on Kubernetes or on a VM with [faasd](https://github.com/openfaas/faasd). Check out the [deployment guide](https://docs.openfaas.com/deployment/) for more information.
Make sure you have the [faas-cli](https://github.com/openfaas/faas-cli) and docker installed to build and deploy functions.

## Tutorial: Query a Postgres database

In this section we will walk through an example showing how to create a function that queries a Postgres database.

We will assume you are already running a Postgres database somewhere. You can use one of the many DBaaS services available, run a postgres with docker or use [arkade](https://github.com/alexellis/arkade) to quickly deploy a database in your cluster. If you are running faasd, the official guide [Serverless For Everyone Else](https://openfaas.gumroad.com/l/serverless-for-everyone-else) has a chapter that shows how to deploy PostgreSQL as an additional service.

You could use a managed PostgreSQL service from AWS, GCP, DigitalOcean, etc, or deploy a development version of PostgreSQL into your Kubernetes cluster using `arkade install postgresql`. After the installation it will print out all the instructions to get the password and connect to the database.

We will create a table and insert some records that can be queried by our function:

```sql
CREATE TABLE IF NOT EXISTS employee
(
    id INT PRIMARY KEY NOT NULL,
    name TEXT NOT NULL,
    email TEXT NOT NULL
);

INSERT INTO employee (id,name,email) VALUES
(1,'Alice','alice@example.com'),
(2,'Bob','bob@example.com');
```

Create a new OpenFaaS function using the `dotnet8-csharp` template. This template is available in the OpenFaaS template store.

```bash
faas-cli template store pull dotnet8-csharp
faas-cli new --lang dotnet8-csharp \
    employee-api
mv employee-api.yml stack.yml
```

```c#
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.DependencyInjection;
using Npgsql;

namespace function;

public static class Handler
{
    // MapEndpoints is used to register WebApplication
    // HTTP handlers for various paths and HTTP methods.
    public static void MapEndpoints(WebApplication app)
    {
        var connectionString = File.ReadAllText("/var/openfaas/secrets/pg-connection");
        var dataSource = NpgsqlDataSource.Create(connectionString);

        app.MapGet("/employees", async () =>
        {   
            var employees = new List<Employee>();
            await using (var cmd = dataSource.CreateCommand("SELECT id, name, email FROM employee"))
            await using (var reader = await cmd.ExecuteReaderAsync())
            {
                while (await reader.ReadAsync())
                {
                    employees.Add(new Employee{
                        Id = (int)reader["id"],
                        Name = reader.GetString(1),
                        Email = reader.GetString(2)
                    });
                }
            }
            return Results.Ok(employees);
        });
    }

    // MapServices can be used to configure additional
    // WebApplication services
    public static void MapServices(IServiceCollection services)
    {
    }
}

public class Employee {
    public int Id { get; set; }
    public string? Name { get; set; }
    public string? Email { get; set; }
}
```

In this example we use [Npgsql](https://www.npgsql.org/) to query a PostgreSQL database. The NuGet package reference for Npgsql should be added the `function.csproj` file for the `employee-api` function. You can use the dotnet CLI for this:

```bash
dotnet add employee-api package Npgsql --version 8.0.2
```

In this example we use Npgsql directly but you could also use [Dapper](https://github.com/DapperLib/Dapper) for less manual object mapping or even [Entity Framework Core](https://learn.microsoft.com/en-us/ef/). The `MapServices` method can be used to register a database context.

The OpenFaaS philosophy is that environment variables should be used for non-confidential configuration values only, and not to inject secrets. That's why we encourage users to use the secrets functionality built into OpenFaaS. See [OpenFaaS secrets](https://docs.openfaas.com/reference/secrets/) for more information.

Save your database connection string in a file `pg-connection` in the `.secrets` directory. By storing secrets in this directory they can be picked up by `faas-cli local-run` which is can be used to run and test functions locally.

> See: [The faster way to iterate on your OpenFaaS functions](https://www.openfaas.com/blog/develop-functions-locally/)

The connection string for Postgres should be formatted like this:

```
Host=postgresql;Username=postgres;Password=mysecretpassword;Database=postgres
```

Before you deploy the function to OpenFaaS make sure the secret exists. This can be done with the faas-cli:

```bash
faas-cli secret create pg-connection \
  --from-file .secrets/pg-connection
```

Update the `stack.yml` file:

```yaml
version: 1.0
provider:
  name: openfaas
  gateway: http://127.0.0.1:8080
functions:
  employee-api:
    lang: dotnet8-csharp
    handler: ./employee-api
    image: ttl.sh/employee-api:latest
    secrets:
      - pg-connection
```

Now we can deploy to Kubernetes using OpenFaaS and faas-cli.

Before you deploy the function make sure the secret exists in your OpenFaaS cluster. This can be done with the faas-cli:

```bash
faas-cli secret create pg-connection \
  --from-file .secrets/pg-connection
```

Next use `faas-cli up` to build and deploy the function.

```
export OPENFAAS_URL="" # Set a remote cluster if you have one available

faas-cli up
```

Invoking the function should return a json response that looks like this:

```bash
$ curl -i $OPENFAAS_URL/function/employee-api/employees

HTTP/1.1 200 OK
Content-Length: 101
Content-Type: application/json
Date: Wed, 17 Apr 2024 10:30:57 GMT
Server: Kestrel
X-Call-Id: 49e750b6-d813-4139-9d4e-96adcf79d596
X-Duration-Seconds: 0.173345
X-Start-Time: 1669895320281999527

[
  {
    "id": 1,
    "name": Slice",
    "email": "alice@example.com"
  },
  {
    "id": 2,
    "name": "Bob",
    "email": "bob@example.com"
  }
]
```

## Dependency Injection

The `MapServices` method in the `Handler` class can be used to register additional services to the dependency injection container.

In this code snippet we register a new database context to query employees using Entity Framework:

```c#
public static class Handler
{
    // MapEndpoints is used to register WebApplication
    // HTTP handlers for various paths and HTTP methods.
    public static void MapEndpoints(WebApplication app)
    {
        app.MapGet("/employees", async (EmployeeDb db) =>
            await db.Employees.ToListAsync());
    }

    // MapServices can be used to configure additional
    // WebApplication services
    public static void MapServices(IServiceCollection services)
    {   
        var connectionString = File.ReadAllText("/var/openfaas/secrets/pg-connection");

        services.AddDbContext<EmployeeDb>(
            optionsBuilder => optionsBuilder.UseNpgsql(connectionString)
        );
    }
}
```

To use Entity Framework Core with our example database model you will need create the database context class `EmployeeDd`. This class is injected into the `/employees` handler and can be used to query the database.

The full example of the `EmployeeDb.cs` file is available on [GitHub](https://github.com/welteki/openfaas-dotnet8-csharp-example/blob/dependency-injection/employee-api/EmployeeDb.cs).

The Entity Framework (EF) Core provider for Npgsql also needs to be added as a dependency to the function. This can be done using the .NET CLI:

```bash
dotnet add employee-api \
  package Npgsql.EntityFrameworkCore.PostgreSQL --version 8.0.2
```

## Add Middleware

The MapEndpoints method gives you access to the `WebApplication` class. This makes it possible to add any existing ASP.NET Core middleware from the function.

In this example we setup a file server to serve static files. Static files can be added in a folder named `static` in the function handler directory. All files in this folder will be copied into the final function image. The static folder is configured as the web root path for the application by default.

To add static files to the `employee-api` function create the static folder:

```bash
mkdir -p employee-api/static
```

We are going to add a basic `index.html` file to the static folder:

```html
<!DOCTYPE html>
<html>
<head>
    <title>Hello from OpenFaaS</title>
</head>
<body>
    <h1>Hello from OpenFaaS</h1>
</body>
</html>
```

Configure the file server middleware in `Handler.cs`:

```c#
public static class Handler
{
    // MapEndpoints is used to register WebApplication
    // HTTP handlers for various paths and HTTP methods.
    public static void MapEndpoints(WebApplication app)
    {
       // Setup the file server to serve static files.
       app.UseFileServer();

       app.MapGet("/employees", async () => .... );
    }

    // MapServices can be used to configure additional
    // WebApplication services
    public static void MapServices(IServiceCollection services)
    {   
    }
}
```

After building and deploying the function again with `faas-cli up` it should now start serving the `index.html` file. You can verify this with curl:

```bash
curl -i $OPENFAAS_URL/function/employee-api/index.html
```

For more information on how to use middleware, see: [ASP.NET Core Middleware](https://learn.microsoft.com/en-us/aspnet/core/fundamentals/middleware/?view=aspnetcore-8.0)

## Conclusion

We walked through a short example to show you how to develop and deploy OpenFaaS function with C#. The new official `dotnet8-csharp` template allows you to quickly develop simple functions or a full featured API. It is based on the APS.NET Core [Minimal API](https://learn.microsoft.com/en-us/aspnet/core/fundamentals/minimal-apis?view=aspnetcore-8.0) style and has full support for dependency injection and other ASP.NET core middleware.

If you already have an existing MVC API or microservice there is no need to rewrite your entire app. You can easily deploy an existing .NET app to OpenFaaS and benefit from all the OpenFaaS abstractions as long as it conforms to the [OpenFaaS workload](https://docs.openfaas.com/reference/workloads/). OpenFaaS makes deploying your apps a much simpler task than it would have been if you tried to program directly against Kubernetes. For a full overview see our blog post: [Build ASP.NET Core APIs with Kubernetes and OpenFaaS](https://www.openfaas.com/blog/asp-net-core/)