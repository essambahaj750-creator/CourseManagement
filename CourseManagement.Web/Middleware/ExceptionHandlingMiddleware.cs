using CourseManagement.Application.Common;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace CourseManagement.Web.Middleware;

public sealed class ExceptionHandlingMiddleware(
    RequestDelegate next,
    ILogger<ExceptionHandlingMiddleware> logger)
{
    public async Task InvokeAsync(HttpContext context)
    {
        try
        {
            await next(context);
        }
        catch (OperationCanceledException) when (context.RequestAborted.IsCancellationRequested)
        {
            // Client disconnected mid-request, commonly during a long upload.
            logger.LogInformation("Request aborted by the client on {Method} {Path}",
                context.Request.Method, context.Request.Path);

            if (!context.Response.HasStarted)
                context.Response.StatusCode = 499;
        }
        catch (Exception exception)
        {
            if (context.Response.HasStarted)
                throw;

            var (status, title, detail) = MapException(exception);
            var isUnexpected = status >= StatusCodes.Status500InternalServerError;

            if (isUnexpected)
            {
                logger.LogError(exception, "Unhandled exception on {Method} {Path}",
                    context.Request.Method, context.Request.Path);
            }
            else
            {
                logger.LogWarning("{ExceptionType} on {Method} {Path}",
                    exception.GetType().Name, context.Request.Method, context.Request.Path);
            }

            var acceptsHtml = context.Request.Headers.Accept
                .ToString()
                .Contains("text/html", StringComparison.OrdinalIgnoreCase);

            if (acceptsHtml)
            {
                context.Response.Clear();
                context.Response.StatusCode = status;
                context.Request.Path = "/Error";
                context.Request.QueryString = new QueryString(
                    $"?statusCode={status}&traceId={Uri.EscapeDataString(context.TraceIdentifier)}");
                await next(context);
                return;
            }

            context.Response.Clear();
            context.Response.StatusCode = status;

            var problem = new ProblemDetails
            {
                Status = status,
                Title = title,
                Detail = detail,
                Instance = context.Request.Path
            };
            problem.Extensions["traceId"] = context.TraceIdentifier;

            // Kept in step with CourseManagement.API: setting Response.ContentType
            // beforehand is overwritten by WriteAsJsonAsync with application/json.
            await context.Response.WriteAsJsonAsync(
                problem,
                options: null,
                contentType: "application/problem+json");
        }
    }

    /// <summary>
    /// Kept in step with CourseManagement.API. Only the two application exception
    /// types have their messages returned; framework exception types are described
    /// generically because their text can carry internal detail.
    /// </summary>
    private static (int Status, string Title, string Detail) MapException(Exception exception) =>
        exception switch
        {
            InvalidRequestException invalidRequest => (
                StatusCodes.Status400BadRequest,
                "Invalid request",
                invalidRequest.Message),
            ConflictException conflict => (
                StatusCodes.Status409Conflict,
                "Conflict",
                conflict.Message),
            ForbiddenAccessException => (
                StatusCodes.Status403Forbidden,
                "Forbidden",
                "You do not have permission to perform this action."),
            UnauthorizedAccessException => (
                StatusCodes.Status401Unauthorized,
                "Unauthorized",
                "Authentication failed or the session is no longer valid."),
            KeyNotFoundException => (
                StatusCodes.Status404NotFound,
                "Resource not found",
                "The requested resource could not be found."),
            ArgumentException => (
                StatusCodes.Status400BadRequest,
                "Invalid request",
                "One or more request values are invalid."),
            DbUpdateException => (
                StatusCodes.Status409Conflict,
                "Data conflict",
                "The operation could not be completed because it conflicts with existing data."),
            _ => (
                StatusCodes.Status500InternalServerError,
                "Internal server error",
                "An unexpected error occurred. Please try again later.")
        };
}
