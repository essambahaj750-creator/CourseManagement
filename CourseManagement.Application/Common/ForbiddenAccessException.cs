namespace CourseManagement.Application.Common;

/// <summary>
/// يُرمى عندما يحاول مستخدم مصادَق عليه تنفيذ عملية لا يملك صلاحيتها
/// (مثل تعديل كورس لا يخصه). يُحوَّل إلى 403 Forbidden في الـ Middleware.
/// </summary>
public class ForbiddenAccessException(string message) : Exception(message);
