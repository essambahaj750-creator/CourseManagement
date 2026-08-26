using CourseManagement.Application.Common;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace CourseManagement.API.Middleware;

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

            // The content type must be passed to WriteAsJsonAsync: setting
            // Response.ContentType beforehand is overwritten with application/json,
            // which hides the RFC 7807 media type from clients that key off it.
            await context.Response.WriteAsJsonAsync(
                problem,
                options: null,
                contentType: "application/problem+json");
        }
    }

    private static (int Status, string Title, string Detail) MapException(Exception exception) =>
        exception switch
        {
            KeyNotFoundException => (
                StatusCodes.Status404NotFound,
                "Resource not found",
                "The requested resource could not be found."),
            ForbiddenAccessException => (
                StatusCodes.Status403Forbidden,
                "Forbidden",
                "You do not have permission to perform this action."),
            UnauthorizedAccessException => (
                StatusCodes.Status401Unauthorized,
                "Unauthorized",
                "Authentication failed or the session is no longer valid."),
            ArgumentException => (
                StatusCodes.Status400BadRequest,
                "Invalid request",
                "One or more request values are invalid."),
            DbUpdateException => (
                StatusCodes.Status409Conflict,
                "Data conflict",
                "The operation could not be completed because it conflicts with existing data."),
            InvalidOperationException invalidOperation => (
                StatusCodes.Status409Conflict,
                "Conflict",
                invalidOperation.Message),
            _ => (
                StatusCodes.Status500InternalServerError,
                "Internal server error",
                "An unexpected error occurred. Please try again later.")
        };
}
