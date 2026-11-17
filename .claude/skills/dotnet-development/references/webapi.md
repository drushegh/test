# ASP.NET Core Web APIs

## Determine the API Style First

Scan the project before writing code: classes inheriting `ControllerBase` /
`[ApiController]` → controllers; `app.MapGet/MapPost/...` → minimal APIs.
Continue with whichever exists; never mix styles in one project. New
projects: default to minimal APIs unless controllers are requested.

## DTOs

Dedicated request/response types — never EF entities (they leak navigation
properties and internals). All DTOs are `sealed record` (immutable,
value equality, CA1852-friendly), with `<summary>` XML doc comments —
on .NET 10+ the built-in OpenAPI generator picks these up once the project
sets `<GenerateDocumentationFile>true</GenerateDocumentationFile>` (.NET 9's
built-in generator ignores XML docs; use `.WithSummary`/`.WithDescription`
or `[EndpointSummary]` there).

```csharp
/// <summary>Represents a product returned by the API.</summary>
public sealed record ProductResponse(
    int Id, string Name, decimal Price, Category Category, DateTimeOffset CreatedAt);

/// <summary>Payload for creating a new product.</summary>
public sealed record CreateProductRequest
{
    [Required, MaxLength(200)]
    public required string Name { get; init; }

    [Range(0.01, 999999.99)]
    public required decimal Price { get; init; }
}
```

Naming: `Create{Entity}Request` / `Update{Entity}Request` /
`{Entity}Response`. Dates: `DateTimeOffset`, never `DateTime`. Enums:
serialise as strings (configure `JsonStringEnumConverter` for both
`ConfigureHttpJsonOptions` and `AddControllers().AddJsonOptions(...)`).

Minimal APIs on .NET 10+: data-annotation validation needs explicit opt-in
— `builder.Services.AddValidation();` (automatic in MVC controllers).

## Endpoints

Organise minimal APIs by resource: one static class per resource with a
`Map{Resource}(this WebApplication app)` extension method, called from
`Program.cs`.

**Prefer `TypedResults` over `Results`** — it embeds response types in the
signature so OpenAPI metadata is inferred. With multiple result types,
annotate the handler's return type explicitly (`Ok<T>` and `NotFound` share
no common base — a bare ternary fails to compile as a route handler):

```csharp
app.MapGet("/api/products/{id}", async Task<Results<Ok<ProductResponse>, NotFound>> (
    int id, IProductService service, CancellationToken cancellationToken) =>
{
    var product = await service.GetByIdAsync(id, cancellationToken);
    return product is null ? TypedResults.NotFound() : TypedResults.Ok(product);
})
.WithName("GetProductById")
.WithSummary("Get a product by ID")
.Produces<ProductResponse>(StatusCodes.Status200OK)
.Produces(StatusCodes.Status404NotFound);
```

`CancellationToken` in every endpoint signature, forwarded to every
downstream async call — lets the server abandon work when clients
disconnect.

**Status codes:**

| Operation | Success | Common errors |
|---|---|---|
| GET (single) | 200 | 404 |
| GET (list) | 200 | — |
| POST (create) | 201 + `Location` header | 400, 409 |
| PUT | 200 | 400, 404 |
| DELETE | 204 | 404, 409 |

POST 201: `CreatedAtAction(nameof(GetById), new { id }, response)` in
controllers; `TypedResults.Created($"/api/products/{id}", response)` in
minimal APIs.

## OpenAPI

.NET 9+: built-in support — `builder.Services.AddOpenApi()` +
`app.MapOpenApi()` (dev), document at `/openapi/v1.json`. **Prefer the
built-in `Microsoft.AspNetCore.OpenApi` on .NET 9+** — the templates dropped
Swashbuckle in .NET 9, so don't add it to new projects by reflex. Swashbuckle
is still maintained and works on .NET 9+; keep it where already installed
(or where you need its generation features) unless asked to remove it. A
UI (Swagger UI / Scalar) is a separate package with either generator.

## Error Handling

Global handler + RFC 7807 Problem Details; no per-endpoint try/catch:

```csharp
builder.Services.AddExceptionHandler<ApiExceptionHandler>();
builder.Services.AddProblemDetails();
app.UseExceptionHandler();
app.UseStatusCodePages();
```

Custom mapping via `IExceptionHandler` (place in `Middleware/`). Map only
**your own domain exception types** — never BCL types like
`ArgumentException`/`InvalidOperationException`/`KeyNotFoundException`:
those are thrown by framework and library code for genuine bugs (a
dictionary miss, a disposed context, an EF query misuse), and mapping them
turns server faults into misleading 4xx responses that hide the 500:

```csharp
internal sealed class ApiExceptionHandler(ILogger<ApiExceptionHandler> logger)
    : IExceptionHandler
{
    public async ValueTask<bool> TryHandleAsync(
        HttpContext httpContext, Exception exception, CancellationToken cancellationToken)
    {
        var (statusCode, title) = exception switch
        {
            // app-defined types, e.g. `public sealed class NotFoundException : Exception`
            NotFoundException => (StatusCodes.Status404NotFound, "Not Found"),
            DomainValidationException => (StatusCodes.Status400BadRequest, "Bad Request"),
            ConflictException => (StatusCodes.Status409Conflict, "Conflict"),
            _ => (0, (string?)null)
        };
        if (statusCode == 0) return false;            // default handler takes it

        // Returning true suppresses exception diagnostics — log first.
        logger.LogWarning(exception, "Handled API exception: {Title}", title);

        httpContext.Response.StatusCode = statusCode;
        await httpContext.Response.WriteAsJsonAsync(new ProblemDetails
        {
            Status = statusCode,
            Title = title,
            Detail = title,    // never exception.Message — may leak internals
            Instance = httpContext.Request.Path
        }, cancellationToken);
        return true;
    }
}
```

## Service Layer

Endpoints don't touch data stores directly. Interface + sealed
implementation owning data access and entity↔DTO mapping; register by
interface — this is what makes handlers testable:

```csharp
public interface IProductService
{
    Task<ProductResponse?> GetByIdAsync(int id, CancellationToken ct);
    Task<ProductResponse> CreateAsync(CreateProductRequest request, CancellationToken ct);
}

builder.Services.AddScoped<IProductService, ProductService>();
```

## .http Test File

After implementing endpoints, add a `.http` file in the project root with
one request per endpoint (realistic bodies, at least one error path, port
matching `launchSettings.json`) — living documentation plus a manual test
harness.

**Local multi-tenant subdomains**: use `tenant1.localhost` — `.localhost`
is reserved for loopback (RFC 6761) and Chromium/Firefox resolve any
`*.localhost` name to 127.0.0.1 with no DNS. Avoid public wildcard-DNS
helpers (`localtest.me`, `nip.io`-style): filtered or corporate DNS often
blocks them (`ERR_NAME_NOT_RESOLVED`). Non-browser clients may still need
help (verify yours): `curl --resolve tenant1.localhost:5001:127.0.0.1 …`
or a `Host:` header.

## Validation Checklist

Status codes per table; 201s carry `Location`; `CancellationToken`
everywhere and forwarded; OpenAPI document loads with metadata on every
endpoint; enums as strings; Problem Details for all errors; no entities in
contracts; DTOs are sealed records with XML docs; `.http` file present;
`dotnet build` zero warnings.
