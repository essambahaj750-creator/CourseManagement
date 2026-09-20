namespace CourseManagement.Application.Common;

/// <summary>
/// يُرمى عندما يكون الإدخال غير صالح بشكل يمكن للمستخدم تصحيحه
/// (مثل امتداد ملف غير مسموح أو حجم يتجاوز الحد). يُحوَّل إلى 400 Bad Request.
/// <para>
/// The message of this exception is written for an end user and is returned to the
/// client verbatim. Never construct it from framework text, an exception message,
/// or any value that could carry internal detail. Use plain
/// <see cref="System.ArgumentException"/> for programmer errors instead — those are
/// reported generically.
/// </para>
/// </summary>
public class InvalidRequestException(string message) : Exception(message);
