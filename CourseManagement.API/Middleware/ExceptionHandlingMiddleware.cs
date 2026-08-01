using CourseManagement.Application.Common;

namespace CourseManagement.API.Middleware;

/// <summary>
/// معالجة مركزية للأخطاء: تحوّل استثناءات منطق الأعمال إلى رموز HTTP صحيحة،
/// وتخفي تفاصيل الأخطاء غير المتوقعة عن العميل (بدل تسريب ex.Message كما كان سابقاً).
/// </summary>
public class ExceptionHandlingMiddleware(RequestDelegate next, ILogger<ExceptionHandlingMiddleware> logger)
{
    public async Task InvokeAsync(HttpContext context)
    {
        try
        {
            await next(context);
        }
        catch (Exception ex)
        {
            if (context.Response.HasStarted)
                throw;

            var (status, title) = ex switch
            {
                KeyNotFoundException => (StatusCodes.Status404NotFound, "Not Found"),
                ForbiddenAccessException => (StatusCodes.Status403Forbidden, "Forbidden"),
                UnauthorizedAccessException => (StatusCodes.Status401Unauthorized, "Unauthorized"),
                InvalidOperationException => (StatusCodes.Status409Conflict, "Conflict"),
                _ => (StatusCodes.Status500InternalServerError, "Internal Server Error")
            };

            if (status == StatusCodes.Status500InternalServerError)
                logger.LogError(ex, "Unhandled exception on {Method} {Path}", context.Request.Method, context.Request.Path);
            else
                logger.LogWarning("{ExceptionType} on {Method} {Path}: {Message}",
                    ex.GetType().Name, context.Request.Method, context.Request.Path, ex.Message);

            context.Response.StatusCode = status;

            var message = status == StatusCodes.Status500InternalServerError
                ? "An unexpected error occurred. Please try again later."
                : ex.Message;

            await context.Response.WriteAsJsonAsync(new
            {
                status,
                title,
                message,
                traceId = context.TraceIdentifier
            });
        }
    }
}
