namespace CourseManagement.Application.Common;

/// <summary>
/// يُرمى عندما يتعارض الطلب مع الحالة الحالية للبيانات
/// (مثل بريد مستخدم بالفعل أو تسجيل مكرر). يُحوَّل إلى 409 Conflict.
/// <para>
/// The message of this exception is written for an end user and is returned to the
/// client verbatim. Never construct it from framework text, an exception message,
/// or any value that could carry internal detail. Use plain
/// <see cref="System.InvalidOperationException"/> for internal invariant and
/// configuration failures instead — those are reported as a generic 500.
/// </para>
/// </summary>
public class ConflictException(string message) : Exception(message);
