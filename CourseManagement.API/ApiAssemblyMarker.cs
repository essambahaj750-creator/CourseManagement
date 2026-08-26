namespace CourseManagement.API;

/// <summary>
/// Stable public handle on this assembly for test hosting.
/// <para>
/// Both CourseManagement.API and CourseManagement.Web use top-level statements,
/// so each generates a <c>Program</c> type in the global namespace. A test project
/// that references both cannot refer to <c>Program</c> by name to locate an entry
/// point, because the simple name is ambiguous across the two assemblies.
/// <c>WebApplicationFactory&lt;T&gt;</c> only uses its type argument to find the
/// containing assembly, so pointing it at this marker resolves the ambiguity
/// without renaming anything or adding an extern alias.
/// </para>
/// </summary>
public sealed class ApiAssemblyMarker;
