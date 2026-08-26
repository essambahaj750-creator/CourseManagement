using CourseManagement.Application.Common;

namespace CourseManagement.Web.Extensions;

public static class ExceptionExtensions
{
    /// <summary>
    /// True when the exception carries a message authored for an end user, and is
    /// therefore safe to render in the UI.
    /// <para>
    /// Controllers use this as an exception filter so that anything unexpected keeps
    /// propagating to <c>ExceptionHandlingMiddleware</c>, which logs it and shows the
    /// error page. Previously every catch block rendered <c>ex.Message</c> directly,
    /// which surfaced internal text — including configuration errors — to users.
    /// </para>
    /// </summary>
    public static bool IsUserFacing(this Exception exception) =>
        exception is InvalidRequestException or ConflictException;
}
